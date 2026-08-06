//
//  SchedulerEngineTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// スケジューラの発火時刻計算と取りこぼし判定を検証する。
/// 仕様: docs/specs/widgets/scheduler.md
@MainActor
struct SchedulerEngineTests {

    private func scheduledJob(
        id: String = "job",
        time: String,
        weekdays: [Int]? = nil,
        enabled: Bool? = nil
    ) -> SchedulerConfig.Job {
        SchedulerConfig.Job(
            id: id,
            name: nil,
            enabled: enabled,
            trigger: .scheduled(time: time, weekdays: weekdays),
            target: .claude(companionIndex: 0),
            prompt: "/test"
        )
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi; c.second = 0
        return Calendar.current.date(from: c)!
    }

    // MARK: - nextFireDate

    @Test("定時ジョブ: 同日の設定時刻がまだ先ならその時刻")
    func nextFireLaterToday() {
        let job = scheduledJob(time: "18:00")
        let now = date(2026, 8, 6, 9, 0)
        let next = SchedulerEngine.nextFireDate(for: job, after: now)

        #expect(next == date(2026, 8, 6, 18, 0))
    }

    @Test("定時ジョブ: 設定時刻を過ぎていたら翌日の同時刻")
    func nextFireRollsToTomorrow() {
        let job = scheduledJob(time: "08:00")
        let now = date(2026, 8, 6, 9, 0)
        let next = SchedulerEngine.nextFireDate(for: job, after: now)

        #expect(next == date(2026, 8, 7, 8, 0))
    }

    @Test("定時ジョブ: 曜日指定があれば該当曜日まで飛ぶ")
    func nextFireSkipsToActiveWeekday() throws {
        // 2026-08-06 は木曜。日曜 (0) のみ有効にすると次は 08-09 (日)
        let now = date(2026, 8, 6, 9, 0)
        #expect(Calendar.current.component(.weekday, from: now) - 1 == 4, "前提: 2026-08-06 は木曜")

        let job = scheduledJob(time: "08:00", weekdays: [0])
        let next = try #require(SchedulerEngine.nextFireDate(for: job, after: now))

        #expect(next == date(2026, 8, 9, 8, 0))
        #expect(Calendar.current.component(.weekday, from: next) - 1 == 0)
    }

    @Test("cron ジョブ: 式に一致する次の分に発火する")
    func nextFireCron() throws {
        let job = SchedulerConfig.Job(
            id: "cron", name: nil, enabled: nil,
            trigger: .cron(expr: "0 */6 * * *"),
            target: .claude(companionIndex: 0), prompt: "/poll"
        )
        let now = date(2026, 8, 6, 9, 30)
        let next = try #require(SchedulerEngine.nextFireDate(for: job, after: now))

        #expect(next == date(2026, 8, 6, 12, 0))
    }

    @Test("時刻がパースできない定時ジョブは次回発火なし")
    func nextFireInvalidTime() {
        let job = scheduledJob(time: "ではない")
        #expect(SchedulerEngine.nextFireDate(for: job, after: date(2026, 8, 6, 9, 0)) == nil)
    }

    @Test("onLaunch / manual は時刻発火しない")
    func nextFireNonTimeTriggers() {
        let now = date(2026, 8, 6, 9, 0)
        let onLaunch = SchedulerConfig.Job(
            id: "l", name: nil, enabled: nil, trigger: .onLaunch,
            target: .terminal(sessionTitle: nil), prompt: "npm run dev"
        )
        let manual = SchedulerConfig.Job(
            id: "m", name: nil, enabled: nil, trigger: .manual,
            target: .terminal(sessionTitle: nil), prompt: "echo hi"
        )

        #expect(SchedulerEngine.nextFireDate(for: onLaunch, after: now) == nil)
        #expect(SchedulerEngine.nextFireDate(for: manual, after: now) == nil)
    }

    // MARK: - pendingOverdue (取りこぼし判定)

    @Test("時刻超過 + 当日未実行 + 有効 なら取りこぼし")
    func overdueDetected() {
        let job = scheduledJob(id: "morning", time: "08:00")
        let overdue = SchedulerEngine.pendingOverdue(
            jobs: [job], isDoneToday: { _ in false }, now: date(2026, 8, 6, 9, 0)
        )
        #expect(overdue == ["morning"])
    }

    @Test("当日実行済みなら取りこぼしにしない")
    func overdueSkipsDoneToday() {
        let job = scheduledJob(id: "morning", time: "08:00")
        let overdue = SchedulerEngine.pendingOverdue(
            jobs: [job], isDoneToday: { _ in true }, now: date(2026, 8, 6, 9, 0)
        )
        #expect(overdue.isEmpty)
    }

    @Test("設定時刻より前なら取りこぼしにしない")
    func overdueSkipsBeforeFireTime() {
        let job = scheduledJob(id: "evening", time: "18:00")
        let overdue = SchedulerEngine.pendingOverdue(
            jobs: [job], isDoneToday: { _ in false }, now: date(2026, 8, 6, 9, 0)
        )
        #expect(overdue.isEmpty)
    }

    @Test("無効ジョブは取りこぼしにしない")
    func overdueSkipsDisabled() {
        let job = scheduledJob(id: "off", time: "08:00", enabled: false)
        let overdue = SchedulerEngine.pendingOverdue(
            jobs: [job], isDoneToday: { _ in false }, now: date(2026, 8, 6, 9, 0)
        )
        #expect(overdue.isEmpty)
    }

    @Test("当日が対象曜日でなければ取りこぼしにしない")
    func overdueSkipsInactiveWeekday() {
        // 2026-08-06 は木曜 (4)。日曜のみ有効なら対象外
        let job = scheduledJob(id: "sunday", time: "08:00", weekdays: [0])
        let overdue = SchedulerEngine.pendingOverdue(
            jobs: [job], isDoneToday: { _ in false }, now: date(2026, 8, 6, 9, 0)
        )
        #expect(overdue.isEmpty)
    }

    @Test("cron / onLaunch / manual は取りこぼしの概念を持たない")
    func overdueOnlyAppliesToScheduled() {
        let cron = SchedulerConfig.Job(
            id: "c", name: nil, enabled: nil, trigger: .cron(expr: "*/5 * * * *"),
            target: .claude(companionIndex: 0), prompt: "/x"
        )
        let onLaunch = SchedulerConfig.Job(
            id: "l", name: nil, enabled: nil, trigger: .onLaunch,
            target: .terminal(sessionTitle: nil), prompt: "x"
        )
        let manual = SchedulerConfig.Job(
            id: "m", name: nil, enabled: nil, trigger: .manual,
            target: .terminal(sessionTitle: nil), prompt: "x"
        )
        let overdue = SchedulerEngine.pendingOverdue(
            jobs: [cron, onLaunch, manual], isDoneToday: { _ in false }, now: date(2026, 8, 6, 23, 0)
        )
        #expect(overdue.isEmpty)
    }
}
