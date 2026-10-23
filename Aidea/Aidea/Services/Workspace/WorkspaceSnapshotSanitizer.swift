//
//  WorkspaceSnapshotSanitizer.swift
//  Aidea
//

import Foundation

/// 復元前のスナップショットから、アプリを落としうる値を取り除く / 範囲内に収める。
/// `workspace.json` はリポジトリに含まれて第三者が書ける入力なので、型として
/// デコードできても値は信用しない (issue #299)。
/// - SessionID.instance が範囲外 → そのタブ / 状態 / 履歴を捨てる
/// - sessions.previews 等で SessionID.tool が一覧の種別と食い違う → その状態を捨てる
/// - Pane.activeIndex が範囲外 → タブ範囲に収める
/// - recommends の defaultCompanionIndex が範囲外 → 0 に戻す
enum WorkspaceSnapshotSanitizer {
    /// SessionID.instance の許容上限。通常は空き番号を小さい順に使うため 2 桁を超えない
    static let maxInstance = 9_999

    static func sanitize(_ snapshot: WorkspaceSnapshot) -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            version: snapshot.version,
            layout: LayoutSnapshot(
                tree: sanitize(snapshot.layout.tree),
                activePaneID: snapshot.layout.activePaneID
            ),
            sessions: sanitize(snapshot.sessions),
            companions: snapshot.companions.map(sanitize),
            recommends: snapshot.recommends.mapValues(sanitize)
        )
    }

    static func isValid(_ id: SessionID) -> Bool {
        (0...maxInstance).contains(id.instance)
    }

    /// activeIndex を tabs の範囲に収める (tabs が空なら 0)
    static func clampedActiveIndex(_ index: Int, tabCount: Int) -> Int {
        max(0, min(index, tabCount - 1))
    }

    /// defaultCompanionIndex をコンパニオンアイコンの範囲に収める (範囲外は 0)
    static func validCompanionIndex(_ index: Int) -> Int {
        CompanionIconPresets.imageIcons.indices.contains(index) ? index : 0
    }

    // MARK: - Private

    private static func sanitize(_ node: LayoutNodeSnapshot) -> LayoutNodeSnapshot {
        switch node {
        case .leaf(let id, let pane):
            let tabs = pane.tabs.filter(isValid)
            return .leaf(id: id, pane: PaneSnapshot(
                paneID: pane.paneID,
                tabs: tabs,
                activeIndex: clampedActiveIndex(pane.activeIndex, tabCount: tabs.count)
            ))
        case .split(let id, let axis, let children):
            return .split(id: id, axis: axis, children: children.map(sanitize))
        }
    }

    private static func sanitize(_ sessions: SessionsSnapshot) -> SessionsSnapshot {
        SessionsSnapshot(
            previews: sessions.previews.filter { $0.id.tool == .preview && isValid($0.id) },
            webs: sessions.webs.filter { $0.id.tool == .web && isValid($0.id) },
            filers: sessions.filers.filter { $0.id.tool == .filer && isValid($0.id) },
            kits: sessions.kits.filter { $0.id.tool == .kit && isValid($0.id) },
            activeHistory: sessions.activeHistory.filter(isValid),
            customTitles: sessions.customTitles?.filter { isValid($0.id) }
        )
    }

    private static func sanitize(_ companion: CompanionConfig) -> CompanionConfig {
        var result = companion
        if let id = companion.sessionID, id.tool != .claude || !isValid(id) {
            result.sessionID = nil
        }
        return result
    }

    private static func sanitize(_ config: SceneConfig) -> SceneConfig {
        SceneConfig(prompts: config.prompts, defaultCompanionIndex: validCompanionIndex(config.defaultCompanionIndex))
    }
}
