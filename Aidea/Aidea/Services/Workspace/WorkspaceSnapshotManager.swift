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
    private static let currentVersion: Int = 8

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

    /// データをデコードし、必要なマイグレーションを適用する。
    /// version フィールドを peek し、v8 → 直デコード / v7 → v8 マイグレーション / v6 以前 → v6→v7→v8 と進める。
    private func decodeAndMigrate(data: Data, projectRoot: URL) -> WorkspaceSnapshot? {
        struct VersionPeek: Decodable { var version: Int }
        let version = (try? JSONDecoder().decode(VersionPeek.self, from: data))?.version ?? 0

        switch version {
        case 8:
            // 現行 (v8) 形式で直接デコード
            return try? JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        case 7:
            // v7 を一旦 LegacyWorkspaceSnapshotV7 として読み、v8 に変換
            if let v7 = try? JSONDecoder().decode(LegacyWorkspaceSnapshotV7.self, from: data) {
                return migrateV7ToV8(v7, projectRoot: projectRoot)
            }
            return nil
        default:
            // v2 - v6 → v7 → v8
            if let legacy = try? JSONDecoder().decode(LegacyWorkspaceSnapshotV6.self, from: data) {
                let v7 = migrateLegacyToV7(legacy: legacy, projectRoot: projectRoot)
                return migrateV7ToV8(v7, projectRoot: projectRoot)
            }
            return nil
        }
    }

    // MARK: - Migration (v2-v6 → v7)

    /// v6 までのスナップショット (フラット構造、UUID コンパニオン、bindings 別配列) を v7 (initialPrompt フィールド残存) に変換する。
    /// 戻り値は LegacyWorkspaceSnapshotV7 で、後段の migrateV7ToV8 が v8 に変換する。
    private func migrateLegacyToV7(legacy: LegacyWorkspaceSnapshotV6, projectRoot: URL) -> LegacyWorkspaceSnapshotV7 {
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

        // 9 個固定の v7 コンパニオン枠を Bundle テンプレで初期化 (initialPrompt はテンプレ既定値)
        var companions = bundleDefaultCompanionsV7()

        // 旧 companions[] を icon 名から index 推定して 9 個枠に配置 (legacy の initialPrompt を引き継ぐ)
        for legacy in legacyCompanions {
            guard let index = inferIndex(fromIcon: legacy.icon),
                  index >= 0, index < companions.count else { continue }
            companions[index] = LegacyCompanionConfigV7(
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

        return LegacyWorkspaceSnapshotV7(
            version: 7,
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

    // MARK: - Migration (v7 → v8)

    /// v7 スナップショットを v8 に変換する (ADR 0022)。
    /// 各 companion.initialPrompt を `.aidea/claude/companions/<index>/instructions.md` に書き出す。
    /// 既存ファイルがある場合は書き出しをスキップしてユーザ編集を保護する (ハイブリッド方式)。
    private func migrateV7ToV8(_ v7: LegacyWorkspaceSnapshotV7, projectRoot: URL) -> WorkspaceSnapshot {
        for legacy in v7.companions {
            writeInstructionsIfAbsent(
                projectRoot: projectRoot,
                index: legacy.index,
                content: legacy.initialPrompt
            )
        }
        let companions = v7.companions.map { legacy in
            CompanionConfig(
                index: legacy.index,
                name: legacy.name,
                icon: legacy.icon,
                sessionID: legacy.sessionID
            )
        }
        return WorkspaceSnapshot(
            version: Self.currentVersion,
            layout: v7.layout,
            sessions: v7.sessions,
            companions: companions,
            recommends: v7.recommends
        )
    }

    /// `.aidea/claude/companions/<index>/instructions.md` を書き出す (ファイル不在時のみ)。
    /// 親ディレクトリは自動生成する。
    private func writeInstructionsIfAbsent(projectRoot: URL, index: Int, content: String) {
        let target = CompanionInstructions.entrypointURL(projectRoot: projectRoot, index: index)
        if FileManager.default.fileExists(atPath: target.path) { return }
        let dir = target.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? content.write(to: target, atomically: true, encoding: .utf8)
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

    /// Bundle テンプレ (`default-workspace.json`、v8) から 9 個固定のコンパニオン初期値を取り出す。
    /// initialPrompt は v8 で削除済みのため CompanionConfig には含まれない。
    private func bundleDefaultCompanions() -> [CompanionConfig] {
        guard let template = loadBundleTemplate() else {
            // 最後の手段: 動的にミニマル 9 個生成 (本来到達しない)
            return (0..<9).map {
                CompanionConfig(
                    index: $0,
                    name: "Companion \($0 + 1)",
                    icon: "Companions/companion-\($0 + 1)",
                    sessionID: nil
                )
            }
        }
        return template.companions
    }

    /// v6 → v7 マイグレーション用に、initialPrompt 付きの 9 個固定枠を返す。
    /// initialPrompt の既定文字列は Bundle 同梱 `companion-instructions.md` (v8 テンプレ本体) を使い、
    /// v7 → v8 マイグレーションでファイル化されると Bundle テンプレと同じ内容になる。
    private func bundleDefaultCompanionsV7() -> [LegacyCompanionConfigV7] {
        let defaults = bundleDefaultCompanions()
        let initialPrompt = bundleDefaultInstructionsText()
        return defaults.map {
            LegacyCompanionConfigV7(
                index: $0.index,
                name: $0.name,
                icon: $0.icon,
                initialPrompt: initialPrompt,
                sessionID: nil
            )
        }
    }

    /// Bundle 同梱 `companion-instructions.md` の本文を返す。読み込み失敗時はミニマルな互換テキスト。
    private func bundleDefaultInstructionsText() -> String {
        if let url = Bundle.main.url(forResource: "companion-instructions", withExtension: "md"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return ".aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね"
    }

    // MARK: - Apply

    /// スナップショットを layout / registry に適用する。
    /// `projectRoot` が渡された場合、最後に `CompanionRosterWriter.writeRoster` で
    /// `.aidea/claude/aidea.md` のコンパニオン名簿セクションを最新の name で書き換える
    /// (詳細: docs/specs/backchannels/companion-roster.md)。
    func apply(_ snapshot: WorkspaceSnapshot, to layout: LayoutConfig, registry: SessionRegistry,
                companionStore: CompanionStore? = nil, speechQueue: SpeechQueue? = nil,
                projectRoot: URL? = nil) {
        // レイアウトツリーを復元
        layout.root = buildLayoutNode(from: snapshot.layout.tree)

        // Companions を復元 (sessionID 統合済み)
        companionStore?.companions = snapshot.companions

        // Recommends を復元
        RecommendStore.setAll(snapshot.recommends)

        // Claude セッションの ensureSession + companionPrompt / companionIndex 再注入
        // (sessionID != nil な companion それぞれに対して)
        // v8 以降は CompanionInstructions.loadCommand(for:) で固定パターン文字列を生成 (ADR 0022)
        if let companionStore {
            for companion in companionStore.companions {
                guard let sessionID = companion.sessionID else { continue }
                let session = registry.ensureSession(for: sessionID)
                if let state = session.state as? ClaudeSessionState {
                    state.companionPrompt = CompanionInstructions.loadCommand(for: companion.index)
                    state.companionIndex = companion.index
                    state.speechQueue = speechQueue
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

        // .aidea/claude/aidea.md のコンパニオン名簿セクションを最新の name に同期する
        // (aidea.md が不在なら no-op、内容が同一なら書き込みスキップ)
        if let projectRoot, let companions = companionStore?.companions {
            CompanionRosterWriter.writeRoster(projectRoot: projectRoot, companions: companions)
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
