//
//  WorkspaceSnapshotSanitizerTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// リポジトリ由来の workspace.json に含まれうる不正値が、復元前に除去 / 補正されることを検証する (issue #299)。
@MainActor
struct WorkspaceSnapshotSanitizerTests {

    private func decode(_ json: String) throws -> WorkspaceSnapshot {
        try JSONDecoder().decode(WorkspaceSnapshot.self, from: Data(json.utf8))
    }

    /// layout / sessions / recommends を差し替えられる最小の v8 スナップショット JSON
    private func snapshotJSON(
        tabs: String = #"[{"tool":"terminal","instance":0}]"#,
        activeIndex: Int = 0,
        sessions: String = #""previews":[],"webs":[],"filers":[],"kits":[],"activeHistory":[]"#,
        companions: String = "[]",
        recommends: String = "{}"
    ) -> String {
        """
        {
          "version": 8,
          "layout": {
            "tree": {"leaf": {"id": "00000000-0000-0000-0000-000000000001",
                              "pane": {"paneID": "00000000-0000-0000-0000-000000000002",
                                       "tabs": \(tabs), "activeIndex": \(activeIndex)}}},
            "activePaneID": null
          },
          "sessions": {\(sessions)},
          "companions": \(companions),
          "recommends": \(recommends)
        }
        """
    }

    private func pane(of snapshot: WorkspaceSnapshot) -> PaneSnapshot? {
        if case .leaf(_, let pane) = snapshot.layout.tree { return pane }
        return nil
    }

    @Test("種別の食い違う Preview / Web / Filer / Kit の状態は捨てる (F13)")
    func dropsMismatchedSessionStates() throws {
        let raw = try decode(snapshotJSON(sessions: """
            "previews":[{"id":{"tool":"web","instance":0}},{"id":{"tool":"preview","instance":1}}],
            "webs":[{"id":{"tool":"preview","instance":0},"url":"https://example.com"}],
            "filers":[{"id":{"tool":"kit","instance":0},"expandedURLs":[]}],
            "kits":[{"id":{"tool":"filer","instance":0},"expandedSections":[],"expandedGroups":[]}],
            "activeHistory":[]
            """))
        let sessions = WorkspaceSnapshotSanitizer.sanitize(raw).sessions

        #expect(sessions.previews.map(\.id) == [SessionID(.preview, instance: 1)])
        #expect(sessions.webs.isEmpty)
        #expect(sessions.filers.isEmpty)
        #expect(sessions.kits.isEmpty)
    }

    @Test("範囲外の defaultCompanionIndex は 0 に戻し、範囲内はそのまま (F16 / F22)")
    func clampsDefaultCompanionIndex() throws {
        let raw = try decode(snapshotJSON(recommends: """
            {"a":{"prompts":["x"],"defaultCompanionIndex":-1},
             "b":{"prompts":[],"defaultCompanionIndex":9223372036854775807},
             "c":{"prompts":[],"defaultCompanionIndex":-9223372036854775808},
             "d":{"prompts":[],"defaultCompanionIndex":8}}
            """))
        let recommends = WorkspaceSnapshotSanitizer.sanitize(raw).recommends

        #expect(recommends["a"]?.defaultCompanionIndex == 0)
        #expect(recommends["a"]?.prompts == ["x"])
        #expect(recommends["b"]?.defaultCompanionIndex == 0)
        #expect(recommends["c"]?.defaultCompanionIndex == 0)
        #expect(recommends["d"]?.defaultCompanionIndex == 8)
    }

    @Test("RecommendState は範囲外のコンパニオン番号を受けても左右移動で落ちない (F22)")
    func recommendStateNormalizesCompanionIndex() {
        let state = RecommendState()
        state.activate(prompts: ["x"], companionIndex: Int.max)
        #expect(state.selectedCompanionIndex == 0)
        state.moveLeft()
        #expect(state.selectedCompanionIndex == CompanionIconPresets.imageIcons.count - 1)

        state.selectedCompanionIndex = Int.max
        state.moveRight()
        #expect(state.selectedCompanionIndex == 1)
        state.selectedCompanionIndex = Int.min
        state.moveLeft()
        #expect(state.selectedCompanionIndex == CompanionIconPresets.imageIcons.count - 1)
    }

    @Test("instance が範囲外の SessionID はタブ・履歴・カスタム名・コンパニオン紐付けから除く (F23)")
    func dropsOutOfRangeInstances() throws {
        let raw = try decode(snapshotJSON(
            tabs: #"[{"tool":"terminal","instance":9223372036854775807},{"tool":"terminal","instance":-1},{"tool":"filer","instance":3}]"#,
            activeIndex: 2,
            sessions: """
                "previews":[],"webs":[],"filers":[],"kits":[],
                "activeHistory":[{"tool":"terminal","instance":9223372036854775807},{"tool":"filer","instance":3}],
                "customTitles":[{"id":{"tool":"terminal","instance":-5},"title":"t"}]
                """,
            companions: """
                [{"index":0,"name":"A","icon":"i","sessionID":{"tool":"claude","instance":9223372036854775807}},
                 {"index":1,"name":"B","icon":"i","sessionID":{"tool":"terminal","instance":0}},
                 {"index":2,"name":"C","icon":"i","sessionID":{"tool":"claude","instance":2}}]
                """
        ))
        let sanitized = WorkspaceSnapshotSanitizer.sanitize(raw)

        #expect(pane(of: sanitized)?.tabs == [SessionID(.filer, instance: 3)])
        #expect(pane(of: sanitized)?.activeIndex == 0)
        #expect(sanitized.sessions.activeHistory == [SessionID(.filer, instance: 3)])
        #expect(sanitized.sessions.customTitles?.isEmpty == true)
        #expect(sanitized.companions.map(\.sessionID) == [nil, nil, SessionID(.claude, instance: 2)])
    }

    @Test("負 / 過大な activeIndex はタブ範囲に収める (F24)")
    func clampsActiveIndex() throws {
        let tabs = #"[{"tool":"terminal","instance":0},{"tool":"filer","instance":0}]"#
        let negative = WorkspaceSnapshotSanitizer.sanitize(try decode(snapshotJSON(tabs: tabs, activeIndex: -1)))
        let tooLarge = WorkspaceSnapshotSanitizer.sanitize(try decode(snapshotJSON(tabs: tabs, activeIndex: 99)))
        let empty = WorkspaceSnapshotSanitizer.sanitize(try decode(snapshotJSON(tabs: "[]", activeIndex: 5)))

        #expect(pane(of: negative)?.activeIndex == 0)
        #expect(pane(of: tooLarge)?.activeIndex == 1)
        #expect(pane(of: empty)?.activeIndex == 0)
    }

    @Test("範囲内の値だけのスナップショットは補正で内容が変わらない")
    func leavesValidSnapshotUntouched() throws {
        let raw = try decode(snapshotJSON(
            tabs: #"[{"tool":"terminal","instance":0},{"tool":"filer","instance":1}]"#,
            activeIndex: 1,
            recommends: #"{"terminal":{"prompts":["p"],"defaultCompanionIndex":3}}"#
        ))
        let sanitized = WorkspaceSnapshotSanitizer.sanitize(raw)

        #expect(pane(of: sanitized)?.tabs == pane(of: raw)?.tabs)
        #expect(pane(of: sanitized)?.activeIndex == 1)
        #expect(sanitized.recommends["terminal"]?.defaultCompanionIndex == 3)
    }
}
