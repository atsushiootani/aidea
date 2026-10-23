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
    /// config から読み込んだ有効ジョブ一覧 (設定ファイルの `jobs` 配列順 = 表示順、issue #274)
    private(set) var jobs: [SchedulerConfig.Job] = []
    /// 取りこぼし (当日未実行・時刻超過・有効) のジョブ id 集合 = widget の「未実行」対象
    private(set) var overdueJobIDs: Set<String> = []
    /// ジョブ id → 最終送信日付 `YYYY-MM-DD`
    private(set) var lastRun: [String: String] = [:]
    /// Popover の開閉
    var isPopoverPresented: Bool = false
    /// プロジェクトの scheduler.json の内容がユーザに承認済みか (issue #293)。
    /// 未承認の間はジョブを一覧表示するだけで、定時 / cron / 起動時の自動発火も手動実行もしない。
    private(set) var isTrusted: Bool = true

    @ObservationIgnored
    private let engine = SchedulerEngine()
    @ObservationIgnored
    private var store: SchedulerStore?
    @ObservationIgnored
    private var projectRoot: URL?
    /// 承認記録 (リポジトリ外)。テストでは一時ファイルを指すものを渡す。
    @ObservationIgnored
    private var trustStore = SchedulerTrustStore()
    /// 承認ダイアログ (projectRoot, 対象ジョブ) → 承認されたら true。テストでは差し替える。
    @ObservationIgnored
    private var confirmTrust: (URL, [SchedulerConfig.Job]) -> Bool = SchedulerTrustDialog.show
    /// 現在の `jobs` の元になった config のバイト列。承認時はこのバイト列のハッシュを記録する
    /// (ダイアログで見せた内容と承認する内容を一致させるため、承認時にファイルを読み直さない)。
    @ObservationIgnored
    private var loadedConfigData: Data?
    /// 発火時のセッション送信処理 (target, prompt) を AideaApp が注入する。
    /// 定刻発火・手動実行 (runNow)・起動時実行 (runOnLaunchJobs) の全てから呼ぶ。
    @ObservationIgnored
    private var dispatch: ((SchedulerConfig.Target, String) -> Void)?
    /// システムスリープ復帰通知の購読トークン。
    @ObservationIgnored
    private var wakeObserver: NSObjectProtocol?

    /// ヘッダ widget の集約状態。優先順位は 未承認 > 未実行 > 次回待ち > 全停止。
    enum HeaderStatus: Equatable {
        /// ジョブ設定が未承認 (自動実行を止めている)
        case untrusted
        /// 未実行 (要対応) が N 件
        case overdue(count: Int)
        /// 次回待ち (直近発火の HH:mm)
        case next(time: String)
        /// 有効ジョブが 1 件もない / ジョブ無し
        case idle
    }

    /// 集約ヘッダ状態を算出する。
    var headerStatus: HeaderStatus {
        if !isTrusted {
            return .untrusted
        }
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
    /// config が未承認なら Engine は起動せず、`runOnLaunchJobs` / `runNow` / `requestTrustIfNeeded` で承認を求める。
    func start(
        projectRoot: URL,
        trustStore: SchedulerTrustStore = SchedulerTrustStore(),
        confirmTrust: @escaping (URL, [SchedulerConfig.Job]) -> Bool = SchedulerTrustDialog.show,
        dispatch: @escaping (SchedulerConfig.Target, String) -> Void
    ) {
        let store = SchedulerStore(projectRoot: projectRoot)
        self.store = store
        self.projectRoot = projectRoot
        self.trustStore = trustStore
        self.confirmTrust = confirmTrust
        self.dispatch = dispatch

        engine.onFire = { [weak self] job in
            self?.handleFire(job)
        }

        lastRun = store.loadState().lastRun
        // 取りこぼし判定と次回発火の登録 (承認済みのときだけ) を行う
        applyConfig(store.loadConfigData())

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
        scheduleEngine()
    }

    /// 「今すぐ実行」: 定刻発火と同じ送信を行い、当日実行済みを記録する。
    func runNow(jobID: String) {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return }
        // 無効ジョブは手動実行も不可 (spec Never: 発火時に enabled を確認し、満たさなければ送信しない)
        guard job.isEnabled else { return }
        // 未承認の config のジョブは、内容を見せて承認されるまで手動でも送らない (issue #293)
        guard requestTrustIfNeeded() else { return }
        handleFire(job)
    }

    /// 起動時 (onLaunch) トリガーの有効ジョブを実行する。AideaApp が起動時 (セッション基盤準備後) に呼ぶ。
    /// 毎起動で実行し、実行済み管理は行わない (spec: onLaunch は毎起動)。
    /// 自動発火するジョブ (onLaunch / scheduled / cron) があって config が未承認なら、ここで承認を求める (issue #293)。
    func runOnLaunchJobs() {
        let hasAutoJobs = jobs.contains { $0.isEnabled && ($0.isOnLaunch || $0.isTimed) }
        guard hasAutoJobs, requestTrustIfNeeded() else { return }
        for job in jobs where job.isEnabled && job.isOnLaunch {
            handleFire(job)
        }
    }

    /// ジョブ単位の ON/OFF トグル。config を read-modify-write し、Engine の登録を更新する。
    func toggle(jobID: String) {
        mutateConfig { config in
            guard let idx = config.jobs.firstIndex(where: { $0.id == jobID }) else { return false }
            config.jobs[idx].enabled = !(config.jobs[idx].enabled ?? true)
            return true
        }
    }

    /// ジョブを新規追加する (UI の「＋ 追加」)。
    func addJob(_ job: SchedulerConfig.Job) {
        mutateConfig { config in
            config.jobs.append(job)
            return true
        }
    }

    /// 既存ジョブを更新する (UI の編集)。同 id が無ければ追加扱い。
    func updateJob(_ job: SchedulerConfig.Job) {
        mutateConfig { config in
            if let idx = config.jobs.firstIndex(where: { $0.id == job.id }) {
                config.jobs[idx] = job
            } else {
                config.jobs.append(job)
            }
            return true
        }
    }

    /// ジョブを削除する (UI の削除)。
    func deleteJob(jobID: String) {
        mutateConfig { config in
            config.jobs.removeAll { $0.id == jobID }
            return true
        }
    }

    /// 設定・状態ファイルを再読込し、一覧・ヘッダ表示・次回発火登録を最新化する (issue #274)。
    /// popover を開くたびに呼ばれ、Aidea の外で scheduler.json を編集した場合も再起動なしで反映される。
    /// 内容が承認時から変わっていれば未承認に戻り、自動発火を止める (popover に承認ボタンが出る。issue #293)。
    func reloadFromDisk() {
        guard let store else { return }
        lastRun = store.loadState().lastRun
        applyConfig(store.loadConfigData())
    }

    /// config が未承認なら、実行される内容を見せて承認を求める。承認されたら記録し、自動発火を有効にする。
    /// 既に承認済みなら何もせず true。未承認のまま (拒否 / 未起動) なら false。
    @discardableResult
    func requestTrustIfNeeded() -> Bool {
        if isTrusted { return true }
        guard let projectRoot, let data = loadedConfigData else { return false }
        guard confirmTrust(projectRoot, jobs) else { return false }
        trustStore.trust(projectRoot: projectRoot, configData: data)
        isTrusted = true
        scheduleEngine()
        recomputeOverdue()
        return true
    }

    /// ジョブを並べ替える (issue #274): sourceID のジョブを targetID のジョブの位置へ移動する。
    /// 下方向への移動はターゲットの後、上方向への移動はターゲットの前に入る
    /// (「落とした行の位置を奪う」直感に合わせる)。配列順は設定ファイルに即保存され表示順の SSoT になる。
    func moveJob(sourceID: String, to targetID: String) {
        guard sourceID != targetID else { return }
        mutateConfig { config in
            guard let from = config.jobs.firstIndex(where: { $0.id == sourceID }),
                  let originalTo = config.jobs.firstIndex(where: { $0.id == targetID }) else { return false }
            let job = config.jobs.remove(at: from)
            guard let targetNow = config.jobs.firstIndex(where: { $0.id == targetID }) else { return false }
            config.jobs.insert(job, at: from < originalTo ? targetNow + 1 : targetNow)
            return true
        }
    }

    /// 編集系操作の共通処理: config を read-modify-write で保存し、jobs / Engine / overdue を最新化する。
    /// `body` が false を返したら何も保存しない。
    /// 編集前のファイル内容が承認済みだったときだけ、保存後の内容も承認済みとして記録する
    /// (Aidea の UI での編集はユーザ自身の操作のため再確認しない。未承認の内容を UI 編集で承認済みにはしない)。
    private func mutateConfig(_ body: (inout SchedulerConfig) -> Bool) {
        guard let store, let projectRoot else { return }
        let currentData = store.loadConfigData()
        var config = SchedulerStore.decodeConfig(currentData)
        let wasApproved = isApproved(jobs: config.validJobs(), data: currentData)
        guard body(&config), let newData = store.saveConfig(config) else { return }
        if wasApproved {
            trustStore.trust(projectRoot: projectRoot, configData: newData)
        }
        applyConfig(newData)
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
        // 未承認の config のジョブは送らない (Engine 未登録で通常は来ないが、念のため最終段でも止める)
        guard isTrusted else { return }
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

    /// config のバイト列を jobs に反映し、承認状態を判定して Engine 登録と overdue を作り直す。
    private func applyConfig(_ data: Data?) {
        loadedConfigData = data
        jobs = SchedulerStore.decodeConfig(data).validJobs()
        isTrusted = isApproved(jobs: jobs, data: data)
        scheduleEngine()
        recomputeOverdue()
    }

    /// 指定内容が承認済みか。有効なジョブが 1 件も無ければ実行され得るものが無いので承認不要 (true)。
    private func isApproved(jobs: [SchedulerConfig.Job], data: Data?) -> Bool {
        if jobs.isEmpty { return true }
        guard let projectRoot, let data else { return false }
        return trustStore.isTrusted(projectRoot: projectRoot, configData: data)
    }

    /// 承認済みなら Engine に次回発火を登録し直す。未承認なら登録済みタイマーを全て止める。
    private func scheduleEngine() {
        guard isTrusted else {
            engine.cancelAll()
            return
        }
        engine.schedule(jobs: jobs) { [weak self] id in
            self?.lastRun[id] == SchedulerStore.dateString()
        }
    }

    /// 取りこぼし集合を現在の lastRun / 時刻から再計算する。未承認の間は「未実行」通知を出さない。
    private func recomputeOverdue() {
        guard isTrusted else {
            overdueJobIDs = []
            return
        }
        let today = SchedulerStore.dateString()
        overdueJobIDs = SchedulerEngine.pendingOverdue(
            jobs: jobs,
            isDoneToday: { [weak self] id in self?.lastRun[id] == today }
        )
    }
}
