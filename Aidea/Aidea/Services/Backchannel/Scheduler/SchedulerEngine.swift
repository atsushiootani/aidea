//
//  SchedulerEngine.swift
//  Aidea
//

import Foundation

/// 各ジョブの次回発火時刻を計算し `DispatchQueue.main.asyncAfter` で 1 ジョブ 1 WorkItem 登録する。
/// 発火時に `enabled` + `weekdays` + 当日実行済み (lastRun) を確認して `onFire(job)` を呼び、
/// 発火後は翌日以降の次回分を再登録する (reschedule ループ)。日をまたいでも発火し続ける。
/// 起動時の取りこぼし判定 (`pendingOverdue`) も担う。RemindScheduler の WorkItem パターンを踏襲しつつ
/// 「1 回きり」ではなく「毎日繰り返し」に拡張したもの。
/// docs/specs/widgets/scheduler.md 参照。
@MainActor
final class SchedulerEngine {
    /// 発火時に呼ばれる: (job) -> Void。実際のセッション送信・lastRun 更新は呼び出し側 (SchedulerState) が担う。
    var onFire: ((SchedulerConfig.Job) -> Void)?

    /// jobId → 次回発火タイマー
    private var workItems: [String: DispatchWorkItem] = [:]
    /// 現在登録中のジョブ (jobId → Job)
    private var jobs: [String: SchedulerConfig.Job] = [:]
    /// 当日実行済み判定のためのコールバック。SchedulerState が lastRun を保持する。
    private var isDoneToday: ((String) -> Bool)?

    /// 有効ジョブそれぞれの次回発火を登録する。
    /// `isDoneToday` は発火時点で「当日二重送信」を防ぐために評価する (lastRun 参照)。
    func schedule(jobs jobList: [SchedulerConfig.Job], isDoneToday: @escaping (String) -> Bool) {
        cancelAll()
        self.isDoneToday = isDoneToday
        // タイマー登録は時刻発火するジョブ (scheduled / cron) のみ。onLaunch / manual は時刻発火しない。
        for job in jobList where job.isEnabled && job.isTimed {
            jobs[job.id] = job
            scheduleNext(job, after: Date())
        }
    }

    /// 全タイマーを破棄する。
    func cancelAll() {
        for (_, item) in workItems { item.cancel() }
        workItems.removeAll()
        jobs.removeAll()
    }

    /// 指定ジョブのタイマーだけ破棄する (ON→OFF トグル時)。
    func cancel(jobID: String) {
        workItems.removeValue(forKey: jobID)?.cancel()
        jobs.removeValue(forKey: jobID)
    }

    // MARK: - Overdue (取りこぼし) 判定

    /// 起動時の取りこぼしジョブ id を算出する。
    /// 「有効」かつ「当日が曜日条件を満たす」かつ「当日未実行」かつ「本日の設定時刻を過ぎている」を満たすもの。
    /// 自動実行はせず、widget で「未実行」表示する対象を返す (spec: 取りこぼしは手動実行に委ねる)。
    static func pendingOverdue(
        jobs jobList: [SchedulerConfig.Job],
        isDoneToday: (String) -> Bool,
        now: Date = Date()
    ) -> Set<String> {
        var result = Set<String>()
        let calendar = Calendar.current
        let todayWeekday = (calendar.component(.weekday, from: now) - 1) // 1=Sun → 0=Sun
        // 取りこぼし (未実行通知) も定時ジョブのみが対象。
        for job in jobList where job.isEnabled && job.isScheduled {
            guard job.activeWeekdays.contains(todayWeekday) else { continue }
            guard !isDoneToday(job.id) else { continue }
            guard let fireTime = todayFireTime(for: job, now: now, calendar: calendar) else { continue }
            if fireTime <= now {
                result.insert(job.id)
            }
        }
        return result
    }

    // MARK: - private

    /// `from` 以降で最初に到来する発火時刻を計算して WorkItem を登録する。
    private func scheduleNext(_ job: SchedulerConfig.Job, after from: Date) {
        guard let fireDate = Self.nextFireDate(for: job, after: from) else { return }
        let delay = max(0, fireDate.timeIntervalSinceNow)
        let item = DispatchWorkItem { [weak self] in
            // SchedulerEngine は @MainActor。WorkItem クロージャは @MainActor 推論を受けないため
            // Task { @MainActor } で明示的にメインアクターに乗せてから fire を呼ぶ (Swift 6 strict concurrency 対応)。
            Task { @MainActor [weak self] in
                self?.fire(job)
            }
        }
        workItems[job.id] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// WorkItem 発火時の処理。トリガー種別ごとに送信条件を確認して onFire、その後次回分を再登録する。
    private func fire(_ job: SchedulerConfig.Job) {
        let now = Date()

        // cron は曜日・当日実行済み判定を持たない (式に内包され、周期発火のため二重送信抑止もしない)。
        if job.isCron {
            onFire?(job)
            // 次回分を再登録 (nextDate は分粒度に丸めて +1 分するため現在分は再ヒットしない)
            scheduleNext(job, after: now)
            return
        }

        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: now) - 1
        let alreadyDone = isDoneToday?(job.id) ?? false

        // 曜日条件を満たし、当日未実行のときだけ送信する (二重送信防止)
        if job.activeWeekdays.contains(todayWeekday), !alreadyDone {
            onFire?(job)
        }

        // 次回分を再登録 (今発火した分の直後から探すと当日が再ヒットするので 60 秒進めて探す)
        scheduleNext(job, after: now.addingTimeInterval(60))
    }

    /// `from` より後で job が次に発火する Date を返す。scheduled は曜日条件 (最大 8 日先)、cron は式に従う。
    static func nextFireDate(for job: SchedulerConfig.Job, after from: Date) -> Date? {
        if job.isCron {
            return job.cronExpression?.nextDate(after: from)
        }
        guard let parsed = job.parsedTime else { return nil }
        let calendar = Calendar.current
        let activeWeekdays = Set(job.activeWeekdays)
        for offset in 0...7 {
            guard let base = calendar.date(byAdding: .day, value: offset, to: from) else { continue }
            let weekday = calendar.component(.weekday, from: base) - 1 // 0=Sun
            guard activeWeekdays.contains(weekday) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: base)
            components.hour = parsed.hour
            components.minute = parsed.minute
            components.second = 0
            guard let candidate = calendar.date(from: components) else { continue }
            if candidate > from {
                return candidate
            }
        }
        return nil
    }

    /// job の「本日の設定時刻」の Date を返す (取りこぼし判定用)。
    private static func todayFireTime(for job: SchedulerConfig.Job, now: Date, calendar: Calendar) -> Date? {
        guard let parsed = job.parsedTime else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = parsed.hour
        components.minute = parsed.minute
        components.second = 0
        return calendar.date(from: components)
    }
}
