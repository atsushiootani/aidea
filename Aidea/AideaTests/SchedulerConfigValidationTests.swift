//
//  SchedulerConfigValidationTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// `SchedulerConfig.validJobs()` の不正ジョブ除外 (他ジョブへの巻き込み防止) を検証する。
/// 仕様: docs/specs/widgets/scheduler.md (「不正値は警告ログを出し、当該ジョブをスキップする」、issue #284)
struct SchedulerConfigValidationTests {

    private func job(
        id: String,
        trigger: SchedulerConfig.Trigger = .manual,
        target: SchedulerConfig.Target = .claude(companionIndex: 0),
        prompt: String = "/test"
    ) -> SchedulerConfig.Job {
        SchedulerConfig.Job(id: id, name: nil, enabled: nil, trigger: trigger, target: target, prompt: prompt)
    }

    @Test("時刻パース不可 (25:00 / ではない) の定時ジョブはスキップされる")
    func skipsUnparsableTime() {
        let invalid1 = job(id: "a", trigger: .scheduled(time: "25:00", weekdays: nil))
        let invalid2 = job(id: "b", trigger: .scheduled(time: "ではない", weekdays: nil))
        let valid = job(id: "c", trigger: .scheduled(time: "08:00", weekdays: nil))

        let config = SchedulerConfig(jobs: [invalid1, invalid2, valid])
        #expect(config.validJobs().map(\.id) == ["c"])
    }

    @Test("companionIndex が範囲外 (-1 / 9) のジョブはスキップされる")
    func skipsOutOfRangeCompanionIndex() {
        let invalid1 = job(id: "a", target: .claude(companionIndex: -1))
        let invalid2 = job(id: "b", target: .claude(companionIndex: 9))
        let valid = job(id: "c", target: .claude(companionIndex: 8))

        let config = SchedulerConfig(jobs: [invalid1, invalid2, valid])
        #expect(config.validJobs().map(\.id) == ["c"])
    }

    @Test("id 重複時は先勝ちで 1 件だけ残る")
    func firstWinsOnDuplicateID() {
        let first = job(id: "dup", prompt: "/first")
        let second = job(id: "dup", prompt: "/second")

        let config = SchedulerConfig(jobs: [first, second])
        let result = config.validJobs()

        #expect(result.count == 1)
        #expect(result.first?.prompt == "/first")
    }

    @Test("不正な cron 式のジョブはスキップされる")
    func skipsInvalidCronExpression() {
        let invalid = job(id: "a", trigger: .cron(expr: "60 * * * *"))
        let valid = job(id: "b", trigger: .cron(expr: "*/5 * * * *"))

        let config = SchedulerConfig(jobs: [invalid, valid])
        #expect(config.validJobs().map(\.id) == ["b"])
    }

    @Test("不正ジョブが混ざっていても正常なジョブは残る (巻き込み防止)")
    func invalidJobsDoNotAffectOthers() {
        let jobs = [
            job(id: "good1", trigger: .scheduled(time: "08:00", weekdays: nil)),
            job(id: "bad-time", trigger: .scheduled(time: "25:00", weekdays: nil)),
            job(id: "good2", trigger: .onLaunch, target: .terminal(sessionTitle: nil)),
            job(id: "bad-index", target: .claude(companionIndex: 99)),
            job(id: "bad-cron", trigger: .cron(expr: "not a cron")),
            job(id: "good3", trigger: .manual, target: .terminal(sessionTitle: "logs")),
        ]

        let config = SchedulerConfig(jobs: jobs)
        #expect(config.validJobs().map(\.id) == ["good1", "good2", "good3"])
    }
}
