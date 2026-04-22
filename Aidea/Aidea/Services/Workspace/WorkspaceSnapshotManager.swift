//
//  WorkspaceSnapshotManager.swift
//  Aidea
//

import Foundation

/// ワークスペース (タブ構成・Preview/Web の状態・アクティブセッション) の保存と復元を担う。
/// `<projectRoot>/.aidea/workspace.json` にプロジェクトごとに JSON で書き出す。
final class WorkspaceSnapshotManager {
    /// 現在のスナップショットフォーマットバージョン
    private static let currentVersion: Int = 5

    /// projectRoot から保存先 URL を導出する
    static func fileURL(for projectRoot: URL) -> URL {
        projectRoot
            .appending(path: ".aidea", directoryHint: .isDirectory)
            .appending(path: "workspace.json")
    }

    // MARK: - Save

    /// 現在の layout / registry の状態からスナップショットを作ってファイルに書き出す
    func save(layout: LayoutConfig, registry: SessionRegistry, projectRoot: URL?,
              companionStore: CompanionStore? = nil, recommendStore: (() -> [String: SceneConfig])? = nil) {
        guard let projectRoot = projectRoot else { return }
        let snapshot = buildSnapshot(layout: layout, registry: registry,
                                     companionStore: companionStore, recommendStore: recommendStore)
        let url = Self.fileURL(for: projectRoot)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("[Aidea] Failed to save workspace snapshot: \(error.localizedDescription)")
        }
    }

    /// layout / registry からスナップショット構造体を組み立てる
    private func buildSnapshot(layout: LayoutConfig, registry: SessionRegistry,
                                companionStore: CompanionStore? = nil,
                                recommendStore: (() -> [String: SceneConfig])? = nil) -> WorkspaceSnapshot {
        var previews: [PreviewSnapshot] = []
        var webs: [WebSnapshot] = []
        var filers: [FilerSnapshot] = []
        var kits: [KitSnapshot] = []

        for pane in layout.allPanes {
            for id in pane.tabs {
                switch id.tool {
                case .preview:
                    if let s = registry.session(for: id),
                   let state = s.state as? PreviewSessionState {
                        previews.append(PreviewSnapshot(id: id, url: state.url, title: state.title))
                    }
                case .web:
                    if let s = registry.session(for: id),
                   let state = s.state as? WebSessionState {
                        webs.append(WebSnapshot(id: id, url: state.url))
                    }
                case .filer:
                    if let s = registry.session(for: id),
                   let state = s.state as? FilerSessionState {
                        let live = state.controller.collectExpandedURLs()
                        state.expandedURLs = live
                        filers.append(FilerSnapshot(
                            id: id,
                            expandedURLs: Array(live),
                            excludeRules: state.excludeRules
                        ))
                    }
                case .kit:
                    if let s = registry.session(for: id),
                   let state = s.state as? KitSessionState {
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

        // Companion bindings
        let bindings = companionStore?.activeSessionMap.map {
            CompanionBinding(companionID: $0.key, sessionID: $0.value)
        }

        return WorkspaceSnapshot(
            version: Self.currentVersion,
            layoutRoot: buildLayoutNodeSnapshot(from: layout.root),
            previews: previews,
            webs: webs,
            filers: filers,
            kits: kits,
            activePaneID: registry.activePaneID,
            companions: companionStore?.companions,
            companionBindings: bindings,
            recommends: recommendStore?(),
            activeSessionHistory: registry.activeSessionHistory
        )
    }

    /// LayoutNode ツリーを Codable 型に変換する
    private func buildLayoutNodeSnapshot(from node: LayoutNode) -> LayoutNodeSnapshot {
        switch node.value {
        case .leaf(let pane):
            return .leaf(
                id: node.id,
                pane: PaneSnapshot(paneID: pane.id, tabs: pane.tabs, activeIndex: pane.activeIndex)
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
    func load(projectRoot: URL?) -> WorkspaceSnapshot? {
        guard let projectRoot = projectRoot else { return nil }
        let url = Self.fileURL(for: projectRoot)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard var snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data) else {
            return nil
        }
        // v2 以上なら互換あり（v3 で companions/recommends が Optional 追加されただけ）
        if snapshot.version < 2 {
            return nil
        }

        // v2 → v3 マイグレーション: 旧 companions.json / recommends.json を統合
        if snapshot.companions == nil {
            snapshot = migrateToV3(snapshot: snapshot, projectRoot: projectRoot)
        }

        return snapshot
    }

    /// 旧 companions.json / recommends.json を読み込んで snapshot に統合し、旧ファイルを削除する
    private func migrateToV3(snapshot: WorkspaceSnapshot, projectRoot: URL) -> WorkspaceSnapshot {
        var companions: [CompanionConfig]?
        var bindings: [CompanionBinding]?
        var recommends: [String: SceneConfig]?

        // 旧 companions.json
        let companionsURL = projectRoot.appending(path: ".aidea/companions.json")
        if let data = try? Data(contentsOf: companionsURL) {
            // StoreData 形式を試す
            struct LegacyStoreData: Codable {
                var companions: [CompanionConfig]
                var bindings: [LegacyBinding]
                struct LegacyBinding: Codable {
                    var companionID: UUID
                    var sessionID: SessionID
                }
            }
            if let storeData = try? JSONDecoder().decode(LegacyStoreData.self, from: data) {
                companions = storeData.companions
                bindings = storeData.bindings.map { CompanionBinding(companionID: $0.companionID, sessionID: $0.sessionID) }
            } else if let configs = try? JSONDecoder().decode([CompanionConfig].self, from: data) {
                companions = configs
            }
            try? FileManager.default.removeItem(at: companionsURL)
        }

        // 旧 recommends.json
        let recommendsURL = projectRoot.appending(path: ".aidea/recommends.json")
        if let data = try? Data(contentsOf: recommendsURL) {
            if let dict = try? JSONDecoder().decode([String: SceneConfig].self, from: data) {
                recommends = dict
            } else if let old = try? JSONDecoder().decode([String: [String]].self, from: data) {
                recommends = old.mapValues { SceneConfig(prompts: $0) }
            }
            try? FileManager.default.removeItem(at: recommendsURL)
        }

        return WorkspaceSnapshot(
            version: snapshot.version,
            layoutRoot: snapshot.layoutRoot,
            previews: snapshot.previews,
            webs: snapshot.webs,
            filers: snapshot.filers,
            kits: snapshot.kits,
            activePaneID: snapshot.activePaneID,
            companions: companions,
            companionBindings: bindings,
            recommends: recommends,
            activeSessionHistory: snapshot.activeSessionHistory
        )
    }

    /// スナップショットを layout / registry に適用する
    func apply(_ snapshot: WorkspaceSnapshot, to layout: LayoutConfig, registry: SessionRegistry,
                companionStore: CompanionStore? = nil) {
        // レイアウトツリーを復元
        layout.root = buildLayoutNode(from: snapshot.layoutRoot)

        // Companions / Bindings / Recommends を復元（apply 内で同期的にセット）
        if let companions = snapshot.companions {
            companionStore?.companions = companions
        }
        if let bindings = snapshot.companionBindings {
            companionStore?.activeSessionMap = [:]
            for binding in bindings {
                companionStore?.activeSessionMap[binding.companionID] = binding.sessionID
            }
        }
        if let recommends = snapshot.recommends {
            RecommendStore.setAll(recommends)
        }

        // Claude セッションの ensureSession + companionPrompt セット
        if let companionStore {
            for (companionID, sessionID) in companionStore.activeSessionMap {
                guard let companion = companionStore.companions.first(where: { $0.id == companionID }) else { continue }
                let session = registry.ensureSession(for: sessionID)
                if let state = session.state as? ClaudeSessionState {
                    state.companionPrompt = companion.initialPrompt
                }
            }
        }

        // Preview/Web/Filer/Kit の状態を事前にセット
        for preview in snapshot.previews {
            let session = registry.ensureSession(for: preview.id)
            let state = session.state as! PreviewSessionState
            state.url = preview.url
            state.title = preview.title
        }
        for web in snapshot.webs {
            let session = registry.ensureSession(for: web.id)
            let state = session.state as! WebSessionState
            state.url = web.url
        }
        for filer in snapshot.filers {
            let session = registry.ensureSession(for: filer.id)
            let state = session.state as! FilerSessionState
            state.expandedURLs = Set(filer.expandedURLs)
            // v3 → v4 マイグレーション: 旧スナップショットには excludeRules が無いのでデフォルトを設定
            state.excludeRules = filer.excludeRules ?? FilerSessionState.defaultExcludeRules
        }
        for kit in snapshot.kits {
            let session = registry.ensureSession(for: kit.id)
            let state = session.state as! KitSessionState
            state.expandedSections = Set(kit.expandedSections.compactMap { KitSection(rawValue: $0) })
            state.expandedGroups = Set(kit.expandedGroups)
        }

        // activeSessionHistory を復元 (setActiveTab より前に置くこと。逆だと末尾追加で上書きされる)
        if let history = snapshot.activeSessionHistory {
            registry.restoreActiveSessionHistory(history)
        }

        // Active Pane を復元
        if let activePID = snapshot.activePaneID {
            registry.setActiveTab(paneID: activePID)
        } else if let firstPane = layout.allPanes.first {
            registry.setActiveTab(paneID: firstPane.id)
        }
    }

    /// Codable 型から LayoutNode ツリーを復元する (id を保持して autosaveName 整合を取る)
    private func buildLayoutNode(from snapshot: LayoutNodeSnapshot) -> LayoutNode {
        switch snapshot {
        case .leaf(let id, let paneSnapshot):
            let pane = Pane(id: paneSnapshot.paneID, tabs: paneSnapshot.tabs, activeIndex: paneSnapshot.activeIndex)
            return LayoutNode(id: id, value: .leaf(pane))
        case .split(let id, let axisRaw, let childrenSnapshot):
            let axis = LayoutNode.Axis(rawValue: axisRaw) ?? .horizontal
            let children = childrenSnapshot.map { buildLayoutNode(from: $0) }
            return LayoutNode(id: id, value: .split(axis: axis, children: children))
        }
    }
}
