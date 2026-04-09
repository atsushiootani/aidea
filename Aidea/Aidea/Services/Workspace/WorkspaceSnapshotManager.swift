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
                default:
                    break
                }
            }
        }

        return WorkspaceSnapshot(
            version: 1,
            layout: LayoutSnapshot(
                topLeft: PaneSnapshot(tabs: layout.topLeft.tabs, activeIndex: layout.topLeft.activeIndex),
                bottomLeft: PaneSnapshot(tabs: layout.bottomLeft.tabs, activeIndex: layout.bottomLeft.activeIndex),
                center: PaneSnapshot(tabs: layout.center.tabs, activeIndex: layout.center.activeIndex),
                right: PaneSnapshot(tabs: layout.right.tabs, activeIndex: layout.right.activeIndex)
            ),
            previews: previews,
            webs: webs,
            activeSessionID: registry.activeSessionID
        )
    }

    // MARK: - Load

    /// 保存済みスナップショットを読み込む (無ければ nil)
    func load() -> WorkspaceSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
    }

    /// スナップショットを layout / registry に適用する
    func apply(_ snapshot: WorkspaceSnapshot, to layout: LayoutConfig, registry: SessionRegistry) {
        applyPane(snapshot.layout.topLeft, to: layout.topLeft)
        applyPane(snapshot.layout.bottomLeft, to: layout.bottomLeft)
        applyPane(snapshot.layout.center, to: layout.center)
        applyPane(snapshot.layout.right, to: layout.right)

        // Preview/Web の状態を事前にセットしておく
        // (state(for:) がオンデマンドで初期状態のインスタンスを作ってしまう前に値を注入)
        for preview in snapshot.previews {
            let state = registry.state(for: preview.id) as! PreviewSessionState
            state.url = preview.url
            state.title = preview.title
        }
        for web in snapshot.webs {
            let state = registry.state(for: web.id) as! WebSessionState
            state.url = web.url
        }

        registry.activeSessionID = snapshot.activeSessionID
    }

    /// 1 ペイン分の状態を適用
    private func applyPane(_ snapshot: PaneSnapshot, to pane: Pane) {
        pane.tabs = snapshot.tabs
        let clamped = max(0, min(snapshot.activeIndex, pane.tabs.count - 1))
        pane.activeIndex = pane.tabs.isEmpty ? 0 : clamped
    }
}
