//
//  AideaApp.swift
//  Aidea
//

import SwiftUI
import AppKit

/// アプリのエントリポイント。WorkspaceState / SessionRegistry / LayoutConfig を生成して
/// 全 View に環境配布し、「ディレクトリを開く」メニューとタブ/ツール関連のショートカットを追加する。
/// 起動時にワークスペーススナップショットを読み込み、終了時に保存する。
@main
struct AideaApp: App {
    @State private var workspace: WorkspaceState
    @State private var registry: SessionRegistry
    @State private var layout: LayoutConfig
    @State private var snapshotManager: WorkspaceSnapshotManager
    @State private var speechState: SpeechState
    @State private var companionStore: CompanionStore
    @State private var recommendState: RecommendState
    @State private var handoffState: HandoffState
    /// Ctrl+Tab で起動する Active Session Switcher (Window レベル singleton)
    @State private var sessionSwitcher = ActiveSessionSwitcher()
    /// Cmd+T のツール選択メニューを各ペインの「+」ボタン直下に表示するためのアンカー管理
    @State private var tabPickerAnchor = TabPickerAnchor()

    init() {
        let ws = WorkspaceState()
        let lay = LayoutConfig()
        let reg = SessionRegistry(workspace: ws, layout: lay)
        let speech = SpeechState()
        let companions = CompanionStore()
        let recommend = RecommendState()
        let handoff = HandoffState()
        let manager = WorkspaceSnapshotManager()

        // 起動時に snapshot を読み込んで適用する。読み込めない場合 (Bundle テンプレも失敗) は
        // 緊急フォールバックとして最小レイアウト + ミニマルコンパニオン枠で継続起動する。
        if let snapshot = manager.load(projectRoot: ws.projectRoot) {
            manager.apply(snapshot, to: lay, registry: reg, companionStore: companions, speechQueue: speech.queue)
        } else {
            NSLog("[Aidea] Bundle default-workspace.json も読込失敗。緊急フォールバックを適用")
            lay.root = LayoutConfig.fallbackRoot()
            companions.companions = (0..<9).map {
                CompanionConfig(
                    index: $0,
                    name: "Companion \($0 + 1)",
                    icon: "Companions/companion-\($0 + 1)",
                    sessionID: nil
                )
            }
            if let firstPane = lay.allPanes.first {
                reg.setActiveTab(paneID: firstPane.id, tabIndex: firstPane.activeIndex)
            }
        }

        _workspace = State(initialValue: ws)
        _layout = State(initialValue: lay)
        _registry = State(initialValue: reg)
        _snapshotManager = State(initialValue: manager)
        _speechState = State(initialValue: speech)
        _companionStore = State(initialValue: companions)
        _recommendState = State(initialValue: recommend)
        _handoffState = State(initialValue: handoff)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workspace)
                .environment(registry)
                .environment(layout)
                .environment(speechState)
                .environment(companionStore)
                .environment(recommendState)
                .environment(handoffState)
                .environment(tabPickerAnchor)
                .onAppear {
                    registerTerminationObserver()
                    registerKeyEventMonitor()
                    sessionSwitcher.install(registry: registry, companionStore: companionStore)
                    startHandoff()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("ディレクトリを開く...") {
                    openDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
            tabMenu
            toolMenu
            CommandMenu("Aidea") {
                Button("API キー設定...") {
                    TranslationService.showApiKeyDialog()
                }
            }
        }
    }

    // MARK: - Command menus

    /// タブ・ペイン操作メニュー
    @CommandsBuilder
    private var tabMenu: some Commands {
        CommandMenu("タブ") {
            Button("新しいタブ...") { newTabWithPicker() }
                .keyboardShortcut("t", modifiers: [.command])
            Button("タブを閉じる") { closeCurrentTab() }
                .keyboardShortcut("w", modifiers: [.command])
            Divider()
            Button("左のタブ") { moveTab(offset: -1) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            Button("右のタブ") { moveTab(offset: 1) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Divider()
            Button("前のペイン") { movePane(offset: -1) }
                .keyboardShortcut("[", modifiers: [.command])
            Button("次のペイン") { movePane(offset: 1) }
                .keyboardShortcut("]", modifiers: [.command])
            Divider()
            Button("左右に分割") { splitCurrent(axis: .horizontal) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Button("上下に分割") { splitCurrent(axis: .vertical) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
        }
    }

    /// ツール切替メニュー
    @CommandsBuilder
    private var toolMenu: some Commands {
        CommandMenu("ツール") {
            Button("Filer") { focusTool(.filer) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("Kit") { focusTool(.kit) }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("Git") { focusTool(.git) }
                .keyboardShortcut("3", modifiers: [.command, .option])
            Button("Terminal") { focusTool(.terminal) }
                .keyboardShortcut("7", modifiers: [.command, .option])
            Button("Claude") { focusTool(.claude) }
                .keyboardShortcut("8", modifiers: [.command, .option])
            Button("Web") { focusTool(.web) }
                .keyboardShortcut("9", modifiers: [.command, .option])
            Button("Preview") { focusTool(.preview) }
                .keyboardShortcut("0", modifiers: [.command, .option])
        }
        CommandMenu("コンパニオン") {
            ForEach(0..<9) { index in
                Button("Companion \(index + 1)") { activateCompanion(index: index) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command])
            }
        }
    }

    // MARK: - File menu action

    /// NSOpenPanel を表示してディレクトリ選択を促し、WorkspaceState に反映する
    private func openDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "開く"
        panel.message = "プロジェクトルートを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            workspace.setProjectRoot(url)
        }
    }

    // MARK: - Tab/pane keyboard actions

    /// Cmd+T: アクティブペインの `+` ボタンを押したのと完全に同じ動作を行う。
    private func newTabWithPicker() {
        guard let pane = currentPane() else { return }
        let point = tabPickerAnchor.bottomRightScreenPoint(for: pane.id) ?? NSEvent.mouseLocation
        PaneView.showToolPickerMenu(at: point, pane: pane, layout: layout, registry: registry)
    }

    /// Cmd+W: 現在アクティブなタブを閉じる (メニュー経由)
    private func closeCurrentTab() {
        Self.closeCurrentTabStatic(layout: layout, registry: registry, companionStore: companionStore)
    }

    /// Cmd+Shift+[ / ] : 現在ペイン内でタブを左右に移動 (ラップ)。
    private func moveTab(offset: Int) {
        let lay = layout
        let reg = registry
        DispatchQueue.main.async {
            guard let pane = reg.activePane, !pane.tabs.isEmpty else { return }
            let count = pane.tabs.count
            let newIndex = ((pane.activeIndex + offset) % count + count) % count
            reg.setActiveTab(paneID: pane.id, tabIndex: newIndex)
        }
    }

    /// Cmd+[ / ] : ペイン間をラップで移動。
    private func movePane(offset: Int) {
        let lay = layout
        let reg = registry
        DispatchQueue.main.async {
            let panes = lay.allPanes
            guard !panes.isEmpty else { return }
            let currentIndex: Int
            if let activePID = reg.activePaneID,
               let idx = panes.firstIndex(where: { $0.id == activePID }) {
                currentIndex = idx
            } else {
                currentIndex = 0
            }
            let newIndex = ((currentIndex + offset) % panes.count + panes.count) % panes.count
            let targetPane = panes[newIndex]
            reg.setActiveTab(paneID: targetPane.id, tabIndex: targetPane.activeIndex)
        }
    }

    /// Cmd+Shift+↓ / → : 現在のペインを分割し、新しく作られたペインのタブを active にする
    private func splitCurrent(axis: LayoutNode.Axis) {
        guard let pane = currentPane(), let node = leafNode(for: pane) else { return }
        let reg = registry
        let lay = layout
        DispatchQueue.main.async {
            if let newPane = lay.splitLeaf(node, axis: axis) {
                reg.setActiveTab(paneID: newPane.id, tabIndex: newPane.activeIndex)
            }
        }
    }

    /// Cmd+1..0 : 指定 Tool のタブへフォーカス。既にその Tool がアクティブなら次のインスタンスへ循環。
    /// Cmd+1~8 でコンパニオンを起動またはアクティブにする
    private func activateCompanion(index: Int) {
        guard index < CompanionIconPresets.imageIcons.count,
              index < companionStore.companions.count else { return }
        let companion = companionStore.companion(forIndex: index)

        if let sessionID = companion.sessionID {
            // 既に起動中 → フォーカス
            registry.activateSession(sessionID)
        } else {
            // 未起動 → 起動
            let instance = layout.nextSessionInstance(of: .claude)
            let session = registry.createSession(tool: .claude, instance: instance)
            if let state = session.state as? ClaudeSessionState {
                state.companionPrompt = CompanionInstructions.loadCommand(for: index)
                state.companionIndex = index
                state.speechQueue = speechState.queue
            }
            companionStore.bind(index: index, sessionID: session.id)
            if let pane = registry.activePane ?? layout.allPanes.first {
                pane.tabs.append(session.id)
                registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
            }
        }
    }

    private func focusTool(_ tool: Tool) {
        let matches: [(pane: Pane, id: SessionID, tabIndex: Int)] = layout.allPanes.flatMap { pane in
            pane.tabs.enumerated().compactMap { index, id in
                id.tool == tool ? (pane, id, index) : nil
            }
        }
        guard !matches.isEmpty else { return }
        let targetIndex: Int
        if let activeID = registry.activeSessionID,
           activeID.tool == tool,
           let current = matches.firstIndex(where: { $0.id == activeID }) {
            targetIndex = (current + 1) % matches.count
        } else {
            targetIndex = 0
        }
        let target = matches[targetIndex]
        registry.setActiveTab(paneID: target.pane.id, tabIndex: target.tabIndex)
    }

    // MARK: - Helpers

    /// 現在アクティブなペインを返す (無ければ最初のペイン)
    private func currentPane() -> Pane? {
        return registry.activePane ?? layout.allPanes.first
    }

    /// 指定 Pane を持つ LayoutNode (leaf) を探す
    private func leafNode(for pane: Pane) -> LayoutNode? {
        layout.allLeafNodes.first { node in
            if case .leaf(let p) = node.value {
                return p.id == pane.id
            }
            return false
        }
    }

    /// Cmd+W は SwiftUI が自動生成する File メニューの Close Window と競合するため、
    /// NSEvent のローカル監視でイベントをメニュー経路より前に横取りして自前で処理する。
    private func registerKeyEventMonitor() {
        let layout = self.layout
        let registry = self.registry
        let companionStore = self.companionStore
        let recommend = self.recommendState
        let speechState = self.speechState
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // レコメンドモード中のキー操作
            if recommend.isActive {
                switch event.keyCode {
                case 126: recommend.moveUp(); return nil        // ↑
                case 125: recommend.moveDown(); return nil      // ↓
                case 123: recommend.moveLeft(); return nil      // ←
                case 124: recommend.moveRight(); return nil     // →
                case 36:  // Enter - 送信
                    Self.sendRecommendedPrompt(recommend: recommend, companionStore: companionStore, registry: registry, layout: layout, speechState: speechState)
                    return nil
                case 53:  // Esc - キャンセル
                    recommend.deactivate()
                    return nil
                default:
                    recommend.deactivate()
                    return event
                }
            }

            // Cmd+Enter でレコメンドモード起動
            if event.modifierFlags.contains(.command), event.keyCode == 36 {
                if let activeSession = registry.activeSession,
                   let scene = activeSession.state.currentScene(),
                   let prompts = RecommendStore.prompts(for: scene), !prompts.isEmpty {
                    let defaultCompanion = RecommendStore.defaultCompanionIndex(for: scene)
                    recommend.activate(prompts: prompts, companionIndex: defaultCompanion)
                    return nil
                }
                return event
            }

            // Cmd+Z / Cmd+Shift+Z (Filer の undo / redo)
            // SwiftUI Edit メニューの Undo/Redo は @Environment(\.undoManager) を参照し、
            // AppKit の NSResponder.undoManager を見ない。このため何も渡さないと
            // performKeyEquivalent 段階で disabled 判定 → beep でイベント消費される。
            // Filer がアクティブなときだけ自前で Filer の undoManager.undo()/redo() を呼ぶ。
            if event.modifierFlags.contains(.command),
               !event.modifierFlags.contains(.option),
               !event.modifierFlags.contains(.control),
               event.charactersIgnoringModifiers?.lowercased() == "z" {
                if let activeID = registry.activeSessionID,
                   activeID.tool == .filer,
                   let filerState = registry.session(for: activeID)?.state as? FilerSessionState {
                    let undoManager = filerState.undoManager
                    if event.modifierFlags.contains(.shift) {
                        if undoManager.canRedo { undoManager.redo() }
                    } else {
                        if undoManager.canUndo { undoManager.undo() }
                    }
                    return nil
                }
                return event
            }

            // Cmd+W
            guard event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.shift),
                  !event.modifierFlags.contains(.option),
                  !event.modifierFlags.contains(.control) else {
                return event
            }
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if chars == "w" {
                Self.closeCurrentTabStatic(layout: layout, registry: registry, companionStore: companionStore)
                return nil
            }
            return event
        }
    }

    /// レコメンドモードで選択されたプロンプトをコンパニオンに送信する
    private static func sendRecommendedPrompt(recommend: RecommendState, companionStore: CompanionStore, registry: SessionRegistry, layout: LayoutConfig, speechState: SpeechState) {
        guard let prompt = recommend.selectedPrompt else {
            recommend.deactivate()
            return
        }
        let index = recommend.selectedCompanionIndex
        recommend.deactivate()
        guard index >= 0, index < companionStore.companions.count else { return }
        let companion = companionStore.companion(forIndex: index)

        // 既に起動中ならメッセージを送信
        if let sessionID = companion.sessionID,
           let session = registry.session(for: sessionID),
           let state = session.state as? ClaudeSessionState {
            registry.activateSession(sessionID)
            state.sendMessage(prompt)
            return
        }

        // 未起動 → 起動してから送信
        let instance = layout.nextSessionInstance(of: .claude)
        let session = registry.createSession(tool: .claude, instance: instance)
        if let claudeState = session.state as? ClaudeSessionState {
            claudeState.companionPrompt = CompanionInstructions.loadCommand(for: index)
            claudeState.companionIndex = index
            claudeState.speechQueue = speechState.queue
        }
        companionStore.bind(index: index, sessionID: session.id)
        if let pane = registry.activePane ?? layout.allPanes.first {
            pane.tabs.append(session.id)
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
        }
        // Claude 起動完了 (isReady) を待ってから送信。ready 前でも積んでおけば flush される。
        if let claudeState = session.state as? ClaudeSessionState {
            claudeState.sendMessageWhenReady(prompt)
        }
    }

    // MARK: - Handoff

    /// HandoffState の監視を開始する。projectRoot が未設定なら何もしない。
    /// 受信したハンドオフは `dispatchHandoff` が宛先解決 → Claude セッションへのファイル参照メッセージ送信を行う。
    private func startHandoff() {
        guard let projectRoot = workspace.projectRoot else { return }
        let store = companionStore
        let reg = registry
        let lay = layout
        let state = handoffState
        let speech = speechState
        handoffState.start(projectRoot: projectRoot) { message, url, fromIndex in
            Self.dispatchHandoff(message, handoffURL: url, fromIndex: fromIndex, companionStore: store, registry: reg, layout: lay, handoffState: state, speechState: speech)
        }
    }

    /// ハンドオフメッセージを宛先 Companion に配送する。
    /// PTY には `message` 本文を直接送らず、固定文言のファイル参照メッセージ
    /// (`.aidea/backchannels/<from>/{filename} の作業をやってね`) を送る。本文は受信側 Claude が
    /// handoff-*.json を自ら読んで取得する (docs/specs/backchannels/handoff.md, ADR 0024)。
    /// - 宛先が起動済みなら activateSession → sendMessage (即送信)
    /// - 未起動なら Claude セッションを生成・bind し、`sendMessageWhenReady` で起動完了時に flush させる
    /// 宛先解決失敗時は HandoffState にエラーを通知する。
    private static func dispatchHandoff(
        _ message: HandoffMessage,
        handoffURL: URL,
        fromIndex: Int,
        companionStore: CompanionStore,
        registry: SessionRegistry,
        layout: LayoutConfig,
        handoffState: HandoffState,
        speechState: SpeechState
    ) {
        guard let index = resolveHandoffTarget(message.to, in: companionStore) else {
            handoffState.reportError("ハンドオフ先が解決できません: \(describeTarget(message.to))")
            return
        }
        handoffState.clearError()
        let companion = companionStore.companion(forIndex: index)
        let referenceMessage = ".aidea/backchannels/\(fromIndex)/\(handoffURL.lastPathComponent) の作業をやってね"

        // 起動済み → アクティブ化して ready 状態に応じて送信 (sendMessageWhenReady は即時 or 保留を自動で選ぶ)
        if let sessionID = companion.sessionID,
           let session = registry.session(for: sessionID),
           let claudeState = session.state as? ClaudeSessionState {
            registry.activateSession(sessionID)
            claudeState.sendMessageWhenReady(referenceMessage)
            return
        }

        // 未起動 → 起動してから isReady=true を待って送信
        let instance = layout.nextSessionInstance(of: .claude)
        let session = registry.createSession(tool: .claude, instance: instance)
        if let claudeState = session.state as? ClaudeSessionState {
            claudeState.companionPrompt = CompanionInstructions.loadCommand(for: index)
            claudeState.companionIndex = index
            claudeState.speechQueue = speechState.queue
        }
        companionStore.bind(index: index, sessionID: session.id)
        if let pane = registry.activePane ?? layout.allPanes.first {
            pane.tabs.append(session.id)
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
        }
        if let claudeState = session.state as? ClaudeSessionState {
            claudeState.sendMessageWhenReady(referenceMessage)
        }
    }

    /// HandoffMessage.Target から CompanionStore の index を解決する。
    /// - index 指定は範囲チェックのみ
    /// - name 指定は trim + case-insensitive の先頭マッチ
    private static func resolveHandoffTarget(
        _ target: HandoffMessage.Target,
        in store: CompanionStore
    ) -> Int? {
        switch target {
        case .index(let i):
            guard i >= 0, i < store.companions.count else { return nil }
            return i
        case .name(let raw):
            let needle = raw.trimmingCharacters(in: .whitespaces).lowercased()
            guard !needle.isEmpty else { return nil }
            return store.companions.firstIndex { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == needle }
        }
    }

    /// エラーメッセージ生成用に Target を人間可読な文字列にする
    private static func describeTarget(_ target: HandoffMessage.Target) -> String {
        switch target {
        case .index(let i): return "index=\(i)"
        case .name(let s): return "name=\"\(s)\""
        }
    }

    /// closeCurrentTab のスタティックヘルパ (NSEvent 監視クロージャから呼ぶため)
    private static func closeCurrentTabStatic(layout: LayoutConfig, registry: SessionRegistry, companionStore: CompanionStore? = nil) {
        guard let activeID = registry.activeSessionID,
              let pane = layout.allPanes.first(where: { $0.tabs.contains(activeID) }),
              let index = pane.tabs.firstIndex(of: activeID) else { return }
        pane.tabs.remove(at: index)
        companionStore?.unbindSession(activeID)
        registry.destroySession(activeID)
        if pane.activeIndex >= pane.tabs.count {
            pane.activeIndex = max(0, pane.tabs.count - 1)
        }
        if !pane.tabs.isEmpty {
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.activeIndex)
        }

        if pane.tabs.isEmpty {
            let target = layout.allLeafNodes.first { node in
                if case .leaf(let p) = node.value {
                    return p.id == pane.id
                }
                return false
            }
            if let node = target {
                DispatchQueue.main.async {
                    layout.removeLeaf(node)
                    if let firstPane = layout.allPanes.first {
                        registry.setActiveTab(paneID: firstPane.id, tabIndex: firstPane.activeIndex)
                    }
                }
            }
        }
    }

    /// アプリ終了 / バックグラウンド化時にスナップショットを保存する
    private func registerTerminationObserver() {
        let manager = snapshotManager
        let layout = self.layout
        let registry = self.registry
        let workspace = self.workspace
        let companions = self.companionStore
        let saveAction = {
            manager.save(layout: layout, registry: registry, projectRoot: workspace.projectRoot,
                         companionStore: companions, recommendStore: { RecommendStore.getAll() })
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            saveAction()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            saveAction()
        }
    }
}

