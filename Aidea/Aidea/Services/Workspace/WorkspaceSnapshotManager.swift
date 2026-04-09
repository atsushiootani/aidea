//
//  WorkspaceSnapshotManager.swift
//  Aidea
//

import Foundation

/// ワークスペース (タブ構成・Preview/Web の状態・アクティブセッション) の保存と復元を担う。
/// `~/Library/Application Support/Aidea/workspace.json` に JSON で書き出す。
final class WorkspaceSnapshotManager {
    /// 保存先ファイル URL
    let fileURL: URL
    /// 現在のスナップショットフォーマットバージョン
    private static let currentVersion: Int = 2

    init() {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let dir = support.appending(path: "Aidea", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appending(path: "workspace.json")
    }

    // MARK: - Save

    /// 現在の layout / registry の状態からスナップショットを作ってファイルに書き出す
    func save(layout: LayoutConfig, registry: SessionRegistry) {
        let snapshot = buildSnapshot(layout: layout, registry: registry)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[Aidea] Failed to save workspace snapshot: \(error.localizedDescription)")
        }
    }

    /// layout / registry からスナップショット構造体を組み立てる
    private func buildSnapshot(layout: LayoutConfig, registry: SessionRegistry) -> WorkspaceSnapshot {
        var previews: [PreviewSnapshot] = []
        var webs: [WebSnapshot] = []
        var filers: [FilerSnapshot] = []
        var kits: [KitSnapshot] = []

        for pane in layout.allPanes {
            for id in pane.tabs {
                switch id.tool {
                case .preview:
                    if let state = registry.peekState(for: id) as? PreviewSessionState {
                        previews.append(PreviewSnapshot(id: id, url: state.url, title: state.title))
                    }
                case .web:
                    if let state = registry.peekState(for: id) as? WebSessionState {
                        webs.append(WebSnapshot(id: id, url: state.url))
                    }
                case .filer:
                    if let state = registry.peekState(for: id) as? FilerSessionState {
                        let live = state.controller.collectExpandedURLs()
                        state.expandedURLs = live
                        filers.append(FilerSnapshot(id: id, expandedURLs: Array(live)))
                    }
                case .kit:
                    if let state = registry.peekState(for: id) as? KitSessionState {
                        kits.append(KitSnapshot(
                            id: id,
                            expandedSections: state.expandedSections.map(\.rawValue),
                            expandedGroups: Array(state.expandedGroups)
                        ))
                    }
                default:
                    break
                }
            }
        }

        return WorkspaceSnapshot(
            version: Self.currentVersion,
            layoutRoot: buildLayoutNodeSnapshot(from: layout.root),
            previews: previews,
            webs: webs,
            filers: filers,
            kits: kits,
            activeSessionID: registry.activeSessionID
        )
    }

    /// LayoutNode ツリーを Codable 型に変換する
    private func buildLayoutNodeSnapshot(from node: LayoutNode) -> LayoutNodeSnapshot {
        switch node.value {
        case .leaf(let pane):
            return .leaf(
                id: node.id,
                pane: PaneSnapshot(tabs: pane.tabs, activeIndex: pane.activeIndex)
            )
        case .split(let axis, let children):
            return .split(
                id: node.id,
                axis: axis.rawValue,
                children: children.map { buildLayoutNodeSnapshot(from: $0) }
            )
        }
    }

    // MARK: - Load

    /// 保存済みスナップショットを読み込む (無ければ or 非互換なら nil)
    func load() -> WorkspaceSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data) else {
            return nil
        }
        // version が古い場合は互換性がないので破棄 (既定レイアウトにフォールバック)
        if snapshot.version != Self.currentVersion {
            return nil
        }
        return snapshot
    }

    /// スナップショットを layout / registry に適用する
    func apply(_ snapshot: WorkspaceSnapshot, to layout: LayoutConfig, registry: SessionRegistry) {
        // レイアウトツリーを復元
        layout.root = buildLayoutNode(from: snapshot.layoutRoot)

        // Preview/Web/Filer/Kit の状態を事前にセット
        for preview in snapshot.previews {
            let state = registry.state(for: preview.id) as! PreviewSessionState
            state.url = preview.url
            state.title = preview.title
        }
        for web in snapshot.webs {
            let state = registry.state(for: web.id) as! WebSessionState
            state.url = web.url
        }
        for filer in snapshot.filers {
            let state = registry.state(for: filer.id) as! FilerSessionState
            state.expandedURLs = Set(filer.expandedURLs)
        }
        for kit in snapshot.kits {
            let state = registry.state(for: kit.id) as! KitSessionState
            state.expandedSections = Set(kit.expandedSections.compactMap { KitSection(rawValue: $0) })
            state.expandedGroups = Set(kit.expandedGroups)
        }

        registry.activeSessionID = snapshot.activeSessionID
    }

    /// Codable 型から LayoutNode ツリーを復元する (id を保持して autosaveName 整合を取る)
    private func buildLayoutNode(from snapshot: LayoutNodeSnapshot) -> LayoutNode {
        switch snapshot {
        case .leaf(let id, let paneSnapshot):
            let pane = Pane(tabs: paneSnapshot.tabs, activeIndex: paneSnapshot.activeIndex)
            return LayoutNode(id: id, value: .leaf(pane))
        case .split(let id, let axisRaw, let childrenSnapshot):
            let axis = LayoutNode.Axis(rawValue: axisRaw) ?? .horizontal
            let children = childrenSnapshot.map { buildLayoutNode(from: $0) }
            return LayoutNode(id: id, value: .split(axis: axis, children: children))
        }
    }
}
