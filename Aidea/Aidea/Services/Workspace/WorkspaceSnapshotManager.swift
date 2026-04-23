//
//  WorkspaceSnapshotManager.swift
//  Aidea
//

import Foundation

/// ワークスペース (タブ構成・Preview/Web/Filer/Kit の状態・コンパニオン・レコメンド・履歴) の保存と復元を担う。
/// `<projectRoot>/.aidea/workspace.json` にプロジェクトごとに JSON で書き出す。
/// 初期値の SSoT は Bundle 同梱 `default-workspace.json`。
final class WorkspaceSnapshotManager {
    /// 現在のスナップショットフォーマットバージョン
    private static let currentVersion: Int = 7

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
                            excludeRules: state.excludeRules,
                            userDecorationRules: state.userDecorationRules
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

        let companions = companionStore?.companions ?? []

        return WorkspaceSnapshot(
            version: Self.currentVersion,
            layout: LayoutSnapshot(
                tree: buildLayoutNodeSnapshot(from: layout.root),
                activePaneID: registry.activePaneID
            ),
            sessions: SessionsSnapshot(
                previews: previews,
                webs: webs,
                filers: filers,
                kits: kits,
                activeHistory: registry.activeSessionHistory
            ),
            companions: companions,
            recommends: recommendStore?() ?? [:]
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

    /// ワークスペーススナップショットを読み込む。
    /// 1. `<projectRoot>/.aidea/workspace.json` が存在 → 読込・マイグレーション適用
    /// 2. 不在 → Bundle 同梱の `default-workspace.json` を読込
    /// 3. Bundle 読込も失敗 → nil (AideaApp 側で緊急フォールバック)
    func load(projectRoot: URL?) -> WorkspaceSnapshot? {
        if let projectRoot,
           let data = try? Data(contentsOf: Self.fileURL(for: projectRoot)) {
            return decodeAndMigrate(data: data, projectRoot: projectRoot)
        }
        return loadBundleTemplate()
    }

    /// Bundle 同梱の `default-workspace.json` を読み込む
    private func loadBundleTemplate() -> WorkspaceSnapshot? {
        guard let url = Bundle.main.url(forResource: "default-workspace", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            NSLog("[Aidea] Failed to load default-workspace.json from Bundle")
            return nil
        }
        return try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
    }

    /// データをデコードし、必要なマイグレーションを適用する
    private func decodeAndMigrate(data: Data, projectRoot: URL) -> WorkspaceSnapshot? {
        // 現行 (v7) 形式で直接デコードを試す
        if let snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data) {
            return snapshot
        }
        // 旧 (v2-v6) 形式で読んで v7 にマイグレーションする
        if let legacy = try? JSONDecoder().decode(LegacyWorkspaceSnapshotV6.self, from: data) {
            return migrateLegacyToV7(legacy: legacy, projectRoot: projectRoot)
        }
        return nil
    }

    // MARK: - Migration (v2-v6 → v7)

    /// v6 までのスナップショット (フラット構造、UUID コンパニオン、bindings 別配列) を v7 に変換する
    private func migrateLegacyToV7(legacy: LegacyWorkspaceSnapshotV6, projectRoot: URL) -> WorkspaceSnapshot {
        // v2 → v3 マイグレーション: 旧 .aidea/companions.json / recommends.json を読み込んで統合
        var legacyCompanions: [LegacyCompanionConfig] = legacy.companions ?? []
        var legacyBindings: [LegacyCompanionBinding] = legacy.companionBindings ?? []
        var recommends: [String: SceneConfig] = legacy.recommends ?? [:]
        if legacy.companions == nil {
            let migrated = readLegacyCompanionFiles(projectRoot: projectRoot)
            legacyCompanions = migrated.companions
            legacyBindings = migrated.bindings
            if recommends.isEmpty { recommends = migrated.recommends }
        }

        // 9 個固定のコンパニオン枠を Bundle テンプレで初期化
        var companions = bundleDefaultCompanions()

        // 旧 companions[] を icon 名から index 推定して 9 個枠に配置
        for legacy in legacyCompanions {
            guard let index = inferIndex(fromIcon: legacy.icon),
                  index >= 0, index < companions.count else { continue }
            companions[index] = CompanionConfig(
                index: index,
                name: legacy.name,
                icon: legacy.icon,
                initialPrompt: legacy.initialPrompt,
                sessionID: nil
            )
        }

        // 旧 bindings (UUID → SessionID) を新 sessionID に統合
        for binding in legacyBindings {
            // legacyCompanions の中で companionID 一致する要素の index を求める
            guard let legacy = legacyCompanions.first(where: { $0.id == binding.companionID }),
                  let index = inferIndex(fromIcon: legacy.icon),
                  index >= 0, index < companions.count else { continue }
            companions[index].sessionID = binding.sessionID
        }

        return WorkspaceSnapshot(
            version: Self.currentVersion,
            layout: LayoutSnapshot(
                tree: legacy.layoutRoot,
                activePaneID: legacy.activePaneID
            ),
            sessions: SessionsSnapshot(
                previews: legacy.previews,
                webs: legacy.webs,
                filers: legacy.filers.map { filer in
                    // v3 → v4: excludeRules nil なら FilerSessionState のデフォルト
                    // v5 → v6: userDecorationRules nil なら空配列
                    FilerSnapshot(
                        id: filer.id,
                        expandedURLs: filer.expandedURLs,
                        excludeRules: filer.excludeRules ?? FilerSessionState.defaultExcludeRules,
                        userDecorationRules: filer.userDecorationRules ?? []
                    )
                },
                kits: legacy.kits,
                activeHistory: legacy.activeSessionHistory ?? []
            ),
            companions: companions,
            recommends: recommends
        )
    }

    /// 旧 .aidea/companions.json / .aidea/recommends.json を読み込んで返し、ファイルを削除する
    private func readLegacyCompanionFiles(projectRoot: URL)
        -> (companions: [LegacyCompanionConfig], bindings: [LegacyCompanionBinding], recommends: [String: SceneConfig])
    {
        var companions: [LegacyCompanionConfig] = []
        var bindings: [LegacyCompanionBinding] = []
        var recommends: [String: SceneConfig] = [:]

        // 旧 companions.json
        let companionsURL = projectRoot.appending(path: ".aidea/companions.json")
        if let data = try? Data(contentsOf: companionsURL) {
            struct LegacyStoreData: Codable {
                var companions: [LegacyCompanionConfig]
                var bindings: [LegacyCompanionBinding]
            }
            if let storeData = try? JSONDecoder().decode(LegacyStoreData.self, from: data) {
                companions = storeData.companions
                bindings = storeData.bindings
            } else if let configs = try? JSONDecoder().decode([LegacyCompanionConfig].self, from: data) {
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

        return (companions, bindings, recommends)
    }

    /// アイコン名 (例: "Companions/companion-3") から 0-based index (= 2) を推定する
    private func inferIndex(fromIcon icon: String) -> Int? {
        let prefix = "Companions/companion-"
        guard icon.hasPrefix(prefix) else { return nil }
        let suffix = icon.dropFirst(prefix.count)
        guard let n = Int(suffix), n >= 1, n <= 9 else { return nil }
        return n - 1
    }

    /// Bundle テンプレから 9 個固定のコンパニオン初期値を取り出す
    private func bundleDefaultCompanions() -> [CompanionConfig] {
        guard let template = loadBundleTemplate() else {
            // 最後の手段: 動的にミニマル 9 個生成 (本来到達しない)
            return (0..<9).map {
                CompanionConfig(
                    index: $0,
                    name: "Companion \($0 + 1)",
                    icon: "Companions/companion-\($0 + 1)",
                    initialPrompt: "",
                    sessionID: nil
                )
            }
        }
        return template.companions
    }

    // MARK: - Apply

    /// スナップショットを layout / registry に適用する
    func apply(_ snapshot: WorkspaceSnapshot, to layout: LayoutConfig, registry: SessionRegistry,
                companionStore: CompanionStore? = nil) {
        // レイアウトツリーを復元
        layout.root = buildLayoutNode(from: snapshot.layout.tree)

        // Companions を復元 (sessionID 統合済み)
        companionStore?.companions = snapshot.companions

        // Recommends を復元
        RecommendStore.setAll(snapshot.recommends)

        // Claude セッションの ensureSession + companionPrompt / companionIndex 再注入
        // (sessionID != nil な companion それぞれに対して)
        if let companionStore {
            for companion in companionStore.companions {
                guard let sessionID = companion.sessionID else { continue }
                let session = registry.ensureSession(for: sessionID)
                if let state = session.state as? ClaudeSessionState {
                    state.companionPrompt = companion.initialPrompt
                    state.companionIndex = companion.index
                }
            }
        }

        // Preview/Web/Filer/Kit の状態を事前にセット
        for preview in snapshot.sessions.previews {
            let session = registry.ensureSession(for: preview.id)
            let state = session.state as! PreviewSessionState
            state.url = preview.url
            state.title = preview.title
        }
        for web in snapshot.sessions.webs {
            let session = registry.ensureSession(for: web.id)
            let state = session.state as! WebSessionState
            state.url = web.url
        }
        for filer in snapshot.sessions.filers {
            let session = registry.ensureSession(for: filer.id)
            let state = session.state as! FilerSessionState
            state.expandedURLs = Set(filer.expandedURLs)
            state.excludeRules = filer.excludeRules ?? FilerSessionState.defaultExcludeRules
            state.userDecorationRules = filer.userDecorationRules ?? []
        }
        for kit in snapshot.sessions.kits {
            let session = registry.ensureSession(for: kit.id)
            let state = session.state as! KitSessionState
            state.expandedSections = Set(kit.expandedSections.compactMap { KitSection(rawValue: $0) })
            state.expandedGroups = Set(kit.expandedGroups)
        }

        // activeSessionHistory を復元 (setActiveTab より前に置くこと)
        registry.restoreActiveSessionHistory(snapshot.sessions.activeHistory)

        // Active Pane を復元
        if let activePID = snapshot.layout.activePaneID {
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
