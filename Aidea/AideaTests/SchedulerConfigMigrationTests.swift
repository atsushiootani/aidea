//
//  SchedulerConfigMigrationTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// `SchedulerConfig.Job` の旧スキーマ (time/weekdays/companionIndex) 後方互換マイグレーションを検証する。
/// 仕様: docs/specs/widgets/scheduler.md#マイグレーション-旧スキーマ後方互換 (issue #283)
struct SchedulerConfigMigrationTests {

    private func decodeJob(_ json: String) throws -> SchedulerConfig.Job {
        try JSONDecoder().decode(SchedulerConfig.Job.self, from: Data(json.utf8))
    }

    @Test("旧スキーマ (time/weekdays/companionIndex) は scheduled + claude として読める")
    func decodesOldSchema() throws {
        let json = """
        {"id":"morning","time":"08:00","weekdays":[0,1,2,3,4,5,6],"companionIndex":6,"prompt":"/cc.morning"}
        """
        let job = try decodeJob(json)

        #expect(job.trigger == .scheduled(time: "08:00", weekdays: [0, 1, 2, 3, 4, 5, 6]))
        #expect(job.target == .claude(companionIndex: 6))
    }

    @Test("旧スキーマで weekdays 省略時は毎日 (0...6) になる")
    func oldSchemaWeekdaysOmittedMeansEveryDay() throws {
        let json = """
        {"id":"morning","time":"08:00","companionIndex":6,"prompt":"/cc.morning"}
        """
        let job = try decodeJob(json)

        #expect(job.activeWeekdays == [0, 1, 2, 3, 4, 5, 6])
    }

    @Test("trigger/target と旧フィールドが両方あれば新スキーマが優先される")
    func newSchemaTakesPriorityOverOld() throws {
        let json = """
        {
          "id": "morning",
          "trigger": {"type": "scheduled", "time": "09:00", "weekdays": [1, 2, 3, 4, 5]},
          "target": {"type": "claude", "companionIndex": 2},
          "time": "08:00",
          "weekdays": [0, 6],
          "companionIndex": 6,
          "prompt": "/x"
        }
        """
        let job = try decodeJob(json)

        #expect(job.trigger == .scheduled(time: "09:00", weekdays: [1, 2, 3, 4, 5]))
        #expect(job.target == .claude(companionIndex: 2))
    }

    @Test("旧スキーマで読み込んだジョブは保存時に新スキーマで書き出される")
    func encodesToNewSchemaOnly() throws {
        let job = try decodeJob("""
        {"id":"morning","time":"08:00","weekdays":[0,1,2,3,4,5,6],"companionIndex":6,"prompt":"/cc.morning"}
        """)

        let data = try JSONEncoder().encode(job)
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(raw["time"] == nil)
        #expect(raw["weekdays"] == nil)
        #expect(raw["companionIndex"] == nil)
        #expect(raw["trigger"] != nil)
        #expect(raw["target"] != nil)

        // 往復 (encode → decode) しても内容が保たれる
        let roundTripped = try JSONDecoder().decode(SchedulerConfig.Job.self, from: data)
        #expect(roundTripped == job)
    }

    @Test("trigger も旧 time も無ければ manual になる (現仕様の確認)")
    func fallsBackToManualWithoutAnyTriggerFields() throws {
        let json = """
        {"id":"m","prompt":"/x"}
        """
        let job = try decodeJob(json)

        #expect(job.trigger == .manual)
    }
}
