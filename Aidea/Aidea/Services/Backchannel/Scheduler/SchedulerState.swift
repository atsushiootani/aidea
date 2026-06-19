//
//  SchedulerState.swift
//  Aidea
//

import AppKit
import Foundation
import Observation

/// 定時スケジューラの司令塔。`SchedulerStore` で config/state をロードし、`SchedulerEngine` を起動して
/// 発火コールバックを配線する。UI (SchedulerView / SchedulerPopoverView / SchedulerRowView) は
/// `jobs` / `overdueJobIDs` / `lastRun` / `headerStatus` / `nextFireText` / `isPopoverPresented` を観測する。
/// 発火・手動実行のセッション送信は AideaApp から渡される `dispatch` クロージャに委譲する
/// (RemindState が SpeechQueue へ enqueue するのと同じ「橋渡し」構造)。
/// docs/specs/widgets/scheduler.md 参照。
@MainActor
@Observable
final class SchedulerState {
    /// config から読み込んだ有効ジョブ一覧 (起動時に確定。time 昇順)
    private(set) var jobs: [SchedulerConfig.Job] = []
    /// 取りこぼし (当日未実行・時刻超過・有効) のジョブ id 集合 = widget の「未実行」対象
    private(set) var overdueJobIDs: Set<String> = []
    /// ジョブ id → 最終送信日付 `YYYY-MM-DD`
    private(set) var lastRun: [String: String] = [:]
    /// Popover の開閉
    var isPopoverPresented: Bool = false

    @ObservationIgnored
    private let engine = SchedulerEngine()
    @ObservationIgnored
    private var store: SchedulerStore?
    /// 発火時のセッション送信処理 (target, prompt) を AideaApp が注入する。
    /// 定刻発火・手動実行 (runNow)・起動時実行 (runOnLaunchJobs) の全てから呼ぶ。
    @ObservationIgnored
    private var dispatch: ((SchedulerConfig.Target, String) -> Void)?
    /// システムスリープ復帰通知の購読トークン。
    @ObservationIgnored
    private var wakeObserver: NSObjectProtocol?

    /// ヘッダ widget の集約状態。優先順位は 未実行 > 次回待ち > 全停止。
    enum HeaderStatus: Equatable {
        /// 未実行 (要対応) が N 件
        case overdue(count: Int)
        /// 次回待ち (直近発火の HH:mm)
        case next(time: String)
        /// 有効ジョブが 1 件もない / ジョブ無し
        case idle
    }

    /// 集約ヘッダ状態を算出する。
    var headerStatus: HeaderStatus {
        if !overdueJobIDs.isEmpty {
            return .overdue(count: overdueJobIDs.count)
        }
        if let time = nextFireText {
            return .next(time: time)
        }
        return .idle
    }

    /// 直近の次回発火時刻 `HH:mm` (有効ジョブが無ければ nil)。
    var nextFireText: String? {
        let now = Date()
        let upcoming = jobs
            .filter { $0.isEnabled }
            .compactMap { SchedulerEngine.nextFireDate(for: $0, after: now) }
            .min()
        guard let next = upcoming else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: next)
    }

    /// プロジェクトルートを設定し、config/state をロードして Engine を起動する。
    /// `dispatch` は発火時のセッション送信処理 (companionIndex, command) で、AideaApp が注入する。
    func start(projectRoot: URL, dispatch: @escaping (SchedulerConfig.Target, String) -> Void) {
        let store = SchedulerStore(projectRoot: projectRoot)
        self.store = store
        self.dispatch = dispatch

        let config = store.loadConfig()
        let runState = store.loadState()
        self.lastRun = runState.lastRun
        self.jobs = config.validJobs().sorted { Self.sortKey($0) < Self.sortKey($1) }

        engine.onFire = { [weak self] job in
            self?.handleFire(job)
        }

        // 取りこぼし判定 (起動時)
        let today = SchedulerStore.dateString()
        overdueJobIDs = SchedulerEngine.pendingOverdue(
            jobs: jobs,
            isDoneToday: { [weak self] id in self?.lastRun[id] == today }
        )

        // 次回発火を登録
        engine.schedule(jobs: jobs) { [weak self] id in
            self?.lastRun[id] == SchedulerStore.dateString()
        }

        // スリープ復帰時はタイマーを張り直す。
        // asyncAfter は mach 時間ベースでスリープ中は進まないため、長い遅延 (翌日発火など) が
        // 復帰後にずれる。pmset で 7:55 に wake → reschedule で当日設定時刻の新規タイマーを再登録する。
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reschedule() }
        }
    }

    /// スリープ復帰時に呼ぶ: 取りこぼし再計算 + Engine タイマーを現在時刻基準で張り直す。
    private func reschedule() {
        recomputeOverdue()
        engine.schedule(jobs: jobs) { [weak self] id in
            self?.lastRun[id] == SchedulerStore.dateString()
        }
    }

    /// 「今すぐ実行」: 定刻発火と同じ送信を行い、当日実行済みを記録する。
    func runNow(jobID: String) {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return }
        // 無効ジョブは手動実行も不可 (spec Never: 発火時に enabled を確認し、満たさなければ送信しない)
        guard job.isEnabled else { return }
        handleFire(job)
    }

    /// 起動時 (onLaunch) トリガーの有効ジョブを実行する。AideaApp が起動時 (セッション基盤準備後) に呼ぶ。
    /// 毎起動で実行し、実行済み管理は行わない (spec: onLaunch は毎起動)。
    func runOnLaunchJobs() {
        for job in jobs where job.isEnabled && job.isOnLaunch {
            handleFire(job)
        }
    }

    /// ジョブ単位の ON/OFF トグル。config を read-modify-write し、Engine の登録を更新する。
    func toggle(jobID: String) {
        guard let store else { return }
        var config = store.loadConfig()
        guard let idx = config.jobs.firstIndex(where: { $0.id == jobID }) else { return }
        config.jobs[idx].enabled = !(config.jobs[idx].enabled ?? true)
        persist(config)
    }

    /// ジョブを新規追加する (UI の「＋ 追加」)。
    func addJob(_ job: SchedulerConfig.Job) {
        guard let store else { return }
        var config = store.loadConfig()
        config.jobs.append(job)
        persist(config)
    }

    /// 既存ジョブを更新する (UI の編集)。同 id が無ければ追加扱い。
    func updateJob(_ job: SchedulerConfig.Job) {
        guard let store else { return }
        var config = store.loadConfig()
        if let idx = config.jobs.firstIndex(where: { $0.id == job.id }) {
            config.jobs[idx] = job
        } else {
            config.jobs.append(job)
        }
        persist(config)
    }

    /// ジョブを削除する (UI の削除)。
    func deleteJob(jobID: String) {
        guard let store else { return }
        var config = store.loadConfig()
        config.jobs.removeAll { $0.id == jobID }
        persist(config)
    }

    /// 編集系操作の共通後処理: config を保存し、メモリ上の jobs を更新、Engine を再登録、overdue を再計算する。
    private func persist(_ config: SchedulerConfig) {
        guard let store else { return }
        store.saveConfig(config)
        jobs = config.validJobs().sorted { Self.sortKey($0) < Self.sortKey($1) }
        engine.schedule(jobs: jobs) { [weak self] id in
            self?.lastRun[id] == SchedulerStore.dateString()
        }
        recomputeOverdue()
    }

    /// 指定ジョブが本日実行済みか。
    func isDoneToday(jobID: String) -> Bool {
        lastRun[jobID] == SchedulerStore.dateString()
    }

    /// 指定ジョブが取りこぼし (未実行・要対応) か。
    func isOverdue(jobID: String) -> Bool {
        overdueJobIDs.contains(jobID)
    }

    // MARK: - private

    /// 発火実処理: セッション送信 → lastRun を当日日付で更新 → state 永続化 → overdue 再計算。
    private func handleFire(_ job: SchedulerConfig.Job) {
        dispatch?(job.target, job.prompt)
        // 当日実行済み管理は定時ジョブのみ (onLaunch は毎起動・manual は都度なので記録しない)。
        if job.isScheduled {
            markDone(jobID: job.id)
        }
    }

    /// 当日実行済みを記録し state を書き出す。
    private func markDone(jobID: String) {
        let today = SchedulerStore.dateString()
        lastRun[jobID] = today
        overdueJobIDs.remove(jobID)
        guard let store else { return }
        var runState = store.loadState()
        runState.markDone(id: jobID, today: today)
        store.saveState(runState)
    }

    /// 取りこぼし集合を現在の lastRun / 時刻から再計算する。
    private func recomputeOverdue() {
        let today = SchedulerStore.dateString()
        overdueJobIDs = SchedulerEngine.pendingOverdue(
            jobs: jobs,
            isDoneToday: { [weak self] id in self?.lastRun[id] == today }
        )
    }

    /// ジョブ一覧の表示順キー。定時 (時刻順) → cron (式順) → 起動時 → 手動 の順に並べる。
    private static func sortKey(_ job: SchedulerConfig.Job) -> String {
        switch job.trigger {
        case .scheduled(let time, _): return "0" + time
        case .cron(let expr): return "1" + expr
        case .onLaunch: return "2"
        case .manual: return "3"
        }
    }
}
