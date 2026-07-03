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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var workspace: WorkspaceState
    @State private var registry: SessionRegistry
    @State private var layout: LayoutConfig
    @State private var snapshotManager: WorkspaceSnapshotManager
    @State private var speechState: SpeechState
    @State private var companionStore: CompanionStore
    @State private var recommendState: RecommendState
    @State private var handoffState: HandoffState
    @State private var inboxWatcher = InboxWatcher()
    @State private var outputState: OutputState
    @State private var pomodoroState: PomodoroState
    @State private var quickMemoState: QuickMemoState
    @State private var remindState: RemindState
    @State private var schedulerState: SchedulerState
    @State private var snippetState: SnippetState
    /// Ctrl+Tab で起動する Active Session Switcher (Window レベル singleton)
    @State private var sessionSwitcher = ActiveSessionSwitcher()
    /// Cmd+T のツール選択メニューを各ペインの「+」ボタン直下に表示するためのアンカー管理
    @State private var tabPickerAnchor = TabPickerAnchor()
    /// 自プロセスが取得した排他ロックのトークン (前面化通知の購読に使う)。排他しない素起動時は nil
    @State private var lockToken: String?
    /// 前面化要求の購読 observer (解除用)
    @State private var activationObserver: NSObjectProtocol?
    /// 「最近開いたディレクトリを開く」で MRU ランチャーを sheet 表示するか
    @State private var showLauncher = false

    init() {
        let ws = WorkspaceState()

        // 同一リポジトリの二重起動を排他する (ADR 0030 / window/multi-instance.md)。
        // 既存プロセスが同じリポジトリを開いていれば、前面化要求だけして自プロセスは窓を出さず終了する。
        var acquiredToken: String?
        if let root = ws.projectRoot {
            switch InstanceLock.acquire(for: root) {
            case .heldByOther(let owner):
                InstanceActivationChannel.requestActivation(token: owner.token)
                exit(0)
            case .acquired(let token):
                acquiredToken = token
                RecentProjectsStore.record(root)
            }
        }

        let lay = LayoutConfig()
        let reg = SessionRegistry(workspace: ws, layout: lay)
        let speech = SpeechState()
        let companions = CompanionStore()
        let recommend = RecommendState()
        let handoff = HandoffState()
        let output = OutputState()
        let manager = WorkspaceSnapshotManager()

        // 起動時に snapshot を読み込んで適用する。読み込めない場合 (Bundle テンプレも失敗) は
        // 緊急フォールバックとして最小レイアウト + ミニマルコンパニオン枠で継続起動する。
        if let snapshot = manager.load(projectRoot: ws.projectRoot) {
            manager.apply(snapshot, to: lay, registry: reg, companionStore: companions, speechQueue: speech.queue, projectRoot: ws.projectRoot)
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

        // ポモドーロタイマーは init 時点で onPhaseTransition を組み立てて
        // 自動フェーズ遷移時に concier 役 (companionIndex = 6) で読み上げる。
        // SpeechState が OFF / VOICEVOX 未起動なら voicevox.md のルールに従いスキップ。
        let pomodoro = PomodoroState()
        pomodoro.onPhaseTransition = { newPhase in
            guard speech.isEnabled else { return }
            let text: String
            switch newPhase {
            case .focus:
                text = "休憩終わりです。次の集中タイム始めましょう"
            case .rest:
                text = "集中タイム終わりです。5 分休憩しましょう"
            }
            speech.queue.enqueue(text, speakerId: nil, companionIndex: 6)
        }

        _workspace = State(initialValue: ws)
        _layout = State(initialValue: lay)
        _registry = State(initialValue: reg)
        _snapshotManager = State(initialValue: manager)
        _speechState = State(initialValue: speech)
        _companionStore = State(initialValue: companions)
        _recommendState = State(initialValue: recommend)
        _handoffState = State(initialValue: handoff)
        _outputState = State(initialValue: output)
        _pomodoroState = State(initialValue: pomodoro)
        _quickMemoState = State(initialValue: QuickMemoState())
        _remindState = State(initialValue: RemindState())
        _schedulerState = State(initialValue: SchedulerState())
        _snippetState = State(initialValue: SnippetState())
        _lockToken = State(initialValue: acquiredToken)
    }

    var body: some Scene {
        WindowGroup {
            if workspace.projectRoot == nil {
                // 素起動 (リポジトリ未指定): MRU ランチャーを出す (ADR 0030 / window/multi-instance.md)。
                // 選択したリポジトリは新プロセスで開き、ランチャーのこのプロセスは終了する。
                WorkspaceLauncherView(onSelect: { url in
                    WorkspaceLauncher.openInNewProcess(projectRoot: url)
                    NSApp.terminate(nil)
                })
            } else {
                ContentView()
                    // 複数インスタンスを見分けられるよう、ウィンドウタイトルにリポジトリ名を出す。
                    // Cmd+Tab はアプリ単位集約で別名にできないが、Cmd+` / Exposé / Dock では区別できる。
                    .navigationTitle(workspace.projectRoot.map { "Aidea — \($0.lastPathComponent)" } ?? "Aidea")
                    .environment(workspace)
                    .environment(registry)
                    .environment(layout)
                    .environment(speechState)
                    .environment(companionStore)
                    .environment(recommendState)
                    .environment(handoffState)
                    .environment(outputState)
                    .environment(pomodoroState)
                    .environment(quickMemoState)
                    .environment(remindState)
                    .environment(schedulerState)
                    .environment(snippetState)
                    .environment(tabPickerAnchor)
                    .sheet(isPresented: $showLauncher) {
                        // 「最近開いたディレクトリを開く」: 選択リポジトリは新プロセスで開き、現プロセスは継続する。
                        WorkspaceLauncherView(onSelect: { url in
                            WorkspaceLauncher.openInNewProcess(projectRoot: url)
                            showLauncher = false
                        })
                    }
                    .onAppear {
                        registerTerminationObserver()
                        registerKeyEventMonitor()
                        sessionSwitcher.install(registry: registry, companionStore: companionStore)
                        startHandoff()
                        startInbox()
                        startOutput()
                        startRemind()
                        startScheduler()
                        startSnippet()
                        observeActivationRequests()
                        // 起動時 (onLaunch) ジョブを、セッション基盤が落ち着いてから実行する (ADR 0031)。
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            schedulerState.runOnLaunchJobs()
                        }
                    }
                    .onOpenURL { url in
                        handleExternalOpen(url)
                    }
            }
        }
        .commands {
            // Edit メニューの 取り消す/やり直す を撤去し、マウス経由でも undo が
            // 発火しないようにする (issue #228, ADR 0038)
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .newItem) {
                Button("最近開いたディレクトリを開く...") {
                    showLauncher = true
                }
                Button("ディレクトリを開く...") {
                    openDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
            // View メニュー配下に「タブ」サブメニュー (issue #130)
            CommandGroup(after: .sidebar) {
                Menu("タブ") { tabMenuItems }
            }
            // Aidea メニューに コンパニオン / ツール / 各ウィジェットを集約 (issue #130)
            CommandMenu("Aidea") {
                Menu("コンパニオン") { companionMenuItems }
                Menu("ツール") { toolMenuItems }
                Divider()
                // クイックメモの ⌘M は NSEvent モニターが横取りするため、
                // メニュー項目にはショートカットを付けない (二重定義を避ける。widgets/quick-memo.md)
                Button("クイックメモを開く") { quickMemoState.togglePresented() }
                Button("スニペットを開く") { snippetState.isPopoverPresented.toggle() }
                    .keyboardShortcut("b", modifiers: [.command, .option])
                Button("スケジューラを開く") { schedulerState.isPopoverPresented.toggle() }
                    .keyboardShortcut("s", modifiers: [.command, .option])
                Menu("ポモドーロ") {
                    Button("開始 / 一時停止") { pomodoroState.toggleRun() }
                        .keyboardShortcut("p", modifiers: [.command, .option])
                    Button("リセット") { pomodoroState.reset() }
                        .keyboardShortcut("p", modifiers: [.command, .option, .shift])
                }
                Button("カレンダーを開く") { remindState.isPopoverPresented.toggle() }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                Divider()
                Button("音声入力ダイアログを開く") {
                    VoiceInputLauncher.present(registry: registry, companionStore: companionStore)
                }
                .keyboardShortcut("v", modifiers: [.command, .option])
                .disabled((registry.activeSession?.state as? ClaudeSessionState) == nil)
                Button("読み上げ ON/OFF") {
                    speechState.toggle()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                Divider()
                Button("API キー設定...") {
                    TranslationService.showApiKeyDialog()
                }
            }
        }
    }

    // MARK: - Menu items (issue #130: View > タブ / Aidea > コンパニオン・ツール・ウィジェット)

    /// View > タブ: タブ・ペイン操作
    @ViewBuilder
    private var tabMenuItems: some View {
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

    /// Aidea > コンパニオン: コンパニオン起動 / アクティブ化
    @ViewBuilder
    private var companionMenuItems: some View {
        ForEach(0..<9) { index in
            Button("Companion \(index + 1)") { activateCompanion(index: index) }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command])
        }
    }

    /// Aidea > ツール: ツール切替 (インスタンスの循環フォーカス)
    @ViewBuilder
    private var toolMenuItems: some View {
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
            // 1 プロセス = 1 リポジトリ (ADR 0030)。別リポジトリは現プロセスで差し替えず、常に新プロセスで開く。
            WorkspaceLauncher.openInNewProcess(projectRoot: url)
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
                state.companionPrompt = CompanionInstructions.startupCommand(for: index, projectRoot: workspace.projectRoot)
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
        let quickMemo = self.quickMemoState
        let projectRoot = self.workspace.projectRoot
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // レコメンドモード中のキー操作
            if recommend.isActive {
                switch event.keyCode {
                case 126: recommend.moveUp(); return nil        // ↑
                case 125: recommend.moveDown(); return nil      // ↓
                case 123: recommend.moveLeft(); return nil      // ←
                case 124: recommend.moveRight(); return nil     // →
                case 36:  // Enter - 送信
                    Self.sendRecommendedPrompt(recommend: recommend, companionStore: companionStore, registry: registry, layout: layout, speechState: speechState, projectRoot: projectRoot)
                    return nil
                case 53:  // Esc - キャンセル
                    recommend.deactivate()
                    return nil
                default:
                    recommend.deactivate()
                    return event
                }
            }

            // Cmd+M でクイックメモ popover をトグル (macOS の最小化より前に横取り)
            if event.modifierFlags.contains(.command),
               !event.modifierFlags.contains(.option),
               !event.modifierFlags.contains(.shift),
               !event.modifierFlags.contains(.control),
               event.charactersIgnoringModifiers?.lowercased() == "m" {
                quickMemo.togglePresented()
                return nil
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

            // Cmd+Z / Cmd+Shift+Z は消費して何もしない (issue #228, ADR 0038)。
            // undo に到達する経路 (SwiftUI Edit メニューの @Environment(\.undoManager) /
            // Filer の undoManager) はいずれもクラッシュの余地があり安全に保てないため、
            // アプリ全域で undo/redo キーを無効化する。
            if event.modifierFlags.contains(.command),
               !event.modifierFlags.contains(.option),
               !event.modifierFlags.contains(.control),
               event.charactersIgnoringModifiers?.lowercased() == "z" {
                return nil
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
    private static func sendRecommendedPrompt(recommend: RecommendState, companionStore: CompanionStore, registry: SessionRegistry, layout: LayoutConfig, speechState: SpeechState, projectRoot: URL?) {
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
            claudeState.companionPrompt = CompanionInstructions.startupCommand(for: index, projectRoot: projectRoot)
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

    // MARK: - Output

    /// OutputState の監視を開始する。projectRoot が未設定なら何もしない。
    private func startOutput() {
        guard let projectRoot = workspace.projectRoot else { return }
        outputState.start(projectRoot: projectRoot)
    }

    // MARK: - Remind

    /// RemindState の監視を開始する。projectRoot が未設定なら何もしない。
    /// 発火時に SpeechQueue (= speechState.queue) へ enqueue するため、引数で渡す。
    /// 詳細: docs/specs/backchannels/remind.md
    private func startRemind() {
        guard let projectRoot = workspace.projectRoot else { return }
        remindState.start(projectRoot: projectRoot, speechQueue: speechState.queue)
    }

    // MARK: - Scheduler

    /// SchedulerState を起動する。発火時 (定刻 / 手動「今すぐ実行」の両方) は `dispatchScheduledJob` が
    /// ジョブの companionIndex の Companion セッションへ command を送信する (未起動なら起動して ready 後送信)。
    /// startHandoff と同じ「ローカルキャプチャ → callback」パターン。
    /// 詳細: docs/specs/widgets/scheduler.md
    private func startScheduler() {
        guard let projectRoot = workspace.projectRoot else { return }
        let store = companionStore
        let reg = registry
        let lay = layout
        let speech = speechState
        schedulerState.start(projectRoot: projectRoot) { target, command in
            switch target {
            case .claude(let index):
                Self.dispatchScheduledJob(
                    companionIndex: index, command: command,
                    companionStore: store, registry: reg, layout: lay,
                    speechState: speech, projectRoot: projectRoot
                )
            case .terminal(let sessionTitle):
                Self.sendToTerminal(
                    command: command, sessionTitle: sessionTitle,
                    registry: reg, layout: lay
                )
            }
        }
    }

    /// ターミナルへコマンドを送る共通経路 (スケジューラ Terminal ジョブ / スニペットのタブ名・新規送信で共用)。
    /// (ADR 0031 / 0034)
    /// - `sessionTitle` 指定で同名の生存中ターミナルタブがあれば、それを activate して送る。
    /// - 同名タブが無ければその名前で新規タブを作って送る (フォールバック)。
    /// - `sessionTitle` が nil / 空なら名前なしの新規タブを起動して送る。
    @MainActor
    private static func sendToTerminal(
        command: String,
        sessionTitle: String?,
        registry: SessionRegistry,
        layout: LayoutConfig
    ) {
        let trimmed = sessionTitle?.trimmingCharacters(in: .whitespaces)
        // タブ名指定があり、同名の生存中ターミナルタブがあればそこへ送る。
        if let title = trimmed, !title.isEmpty {
            let existing = layout.allPanes
                .flatMap { $0.tabs }
                .filter { $0.tool == .terminal }
                .compactMap { registry.session(for: $0) }
                .first { registry.tabTitle(for: $0.id) == title }
            if let session = existing, let termState = session.state as? TerminalSessionState {
                registry.activateSession(session.id)
                termState.sendCommand(command)
                return
            }
        }
        // 無ければ新規タブを作成。タブ名指定があれば付与する (次回以降は同名タブに当たる)。
        let instance = layout.nextSessionInstance(of: .terminal)
        let session = registry.createSession(tool: .terminal, instance: instance)
        if let title = trimmed, !title.isEmpty {
            registry.setCustomTitle(title, for: session.id)
        }
        if let pane = registry.activePane ?? layout.allPanes.first {
            pane.tabs.append(session.id)
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
        }
        // PTY (シェル) を起動し、初期化を少し待ってからコマンドを送る (起動直後の取りこぼし回避)。
        if let termState = session.state as? TerminalSessionState {
            _ = termState.terminalView
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                termState.sendCommand(command)
            }
        }
    }

    // MARK: - Snippet

    /// SnippetState を起動する。dispatch クロージャでスニペット実行時のターミナル送信を担う。
    private func startSnippet() {
        guard let projectRoot = workspace.projectRoot else { return }
        let reg = registry
        let lay = layout
        snippetState.start(projectRoot: projectRoot) { command, target in
            Self.dispatchSnippetCommand(command: command, target: target, registry: reg, layout: lay)
        }
    }

    /// スニペットのコマンドを指定ターミナルへ送る。
    /// active: アクティブな Terminal セッション → 全ペインの最初の Terminal → 新規タブ
    /// session(id): 指定セッションへ直接送信 (実行メニューでの明示選択)
    /// tab(title): タブ名で指定 (無ければその名前で新規。スケジューラと共通)
    /// new: 常に新規タブを作成して送信
    @MainActor
    private static func dispatchSnippetCommand(
        command: String,
        target: SnippetState.DispatchTarget,
        registry: SessionRegistry,
        layout: LayoutConfig
    ) {
        switch target {
        case .active:
            if let activeID = registry.activeSessionID,
               activeID.tool == .terminal,
               let termState = registry.session(for: activeID)?.state as? TerminalSessionState {
                termState.sendCommand(command)
                return
            }
            for pane in layout.allPanes {
                for id in pane.tabs where id.tool == .terminal {
                    if let termState = registry.session(for: id)?.state as? TerminalSessionState {
                        registry.activateSession(id)
                        termState.sendCommand(command)
                        return
                    }
                }
            }
            Self.sendToTerminal(command: command, sessionTitle: nil, registry: registry, layout: layout)
        case .session(let id):
            if let termState = registry.session(for: id)?.state as? TerminalSessionState {
                registry.activateSession(id)
                termState.sendCommand(command)
            }
        case .tab(let title):
            Self.sendToTerminal(command: command, sessionTitle: title, registry: registry, layout: layout)
        case .new:
            Self.sendToTerminal(command: command, sessionTitle: nil, registry: registry, layout: layout)
        }
    }

    // MARK: - Instance activation

    /// 同一リポジトリを開こうとした別プロセスからの前面化要求を購読する。
    /// 受信したら自ウィンドウを前面に出す。排他ロックを持たない素起動時 (lockToken == nil) は何もしない。
    private func observeActivationRequests() {
        guard let token = lockToken, activationObserver == nil else { return }
        activationObserver = InstanceActivationChannel.observeActivation(token: token) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    /// スケジューラジョブを `companionIndex` の Companion セッションへ送信する。
    /// - 起動済みなら activateSession → sendMessageWhenReady (即時 or 保留を自動選択)
    /// - 未起動なら Claude セッションを生成・bind・tab 追加し、`sendMessageWhenReady` で ready 後に送信
    /// dispatchHandoff の踏襲だが、宛先 index は解決済みで、送る本文は `command` 文字列そのもの。
    /// docs/specs/widgets/scheduler.md / handoff.md 参照。
    @MainActor
    private static func dispatchScheduledJob(
        companionIndex index: Int,
        command: String,
        companionStore: CompanionStore,
        registry: SessionRegistry,
        layout: LayoutConfig,
        speechState: SpeechState,
        projectRoot: URL?
    ) {
        guard index >= 0, index < companionStore.companions.count else { return }
        let companion = companionStore.companion(forIndex: index)

        // 起動済み → アクティブ化して ready 状態に応じて送信
        if let sessionID = companion.sessionID,
           let session = registry.session(for: sessionID),
           let claudeState = session.state as? ClaudeSessionState {
            registry.activateSession(sessionID)
            claudeState.sendMessageWhenReady(command)
            return
        }

        // 未起動 → 起動してから ready 後に送信
        let instance = layout.nextSessionInstance(of: .claude)
        let session = registry.createSession(tool: .claude, instance: instance)
        if let claudeState = session.state as? ClaudeSessionState {
            claudeState.companionPrompt = CompanionInstructions.startupCommand(for: index, projectRoot: projectRoot)
            claudeState.companionIndex = index
            claudeState.speechQueue = speechState.queue
        }
        companionStore.bind(index: index, sessionID: session.id)
        if let pane = registry.activePane ?? layout.allPanes.first {
            pane.tabs.append(session.id)
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
        }
        if let claudeState = session.state as? ClaudeSessionState {
            claudeState.sendMessageWhenReady(command)
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
            Self.dispatchHandoff(message, handoffURL: url, fromIndex: fromIndex, companionStore: store, registry: reg, layout: lay, handoffState: state, speechState: speech, projectRoot: projectRoot)
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
        speechState: SpeechState,
        projectRoot: URL?
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
            claudeState.companionPrompt = CompanionInstructions.startupCommand(for: index, projectRoot: projectRoot)
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

    // MARK: - Inbox (外部 → Companion)

    /// inbox メッセージ送信時に本文末尾へ付加する「返信不要」文言 (docs/specs/backchannels/inbox.md)。
    private static let inboxNoReplySuffix =
        "\n\n---\n(これは外部から自動送信されたメッセージです。返信を受け取る相手はいないので、返信は不要です。指示された作業だけ行ってください)"

    /// InboxWatcher の監視を開始する。projectRoot が未設定なら何もしない。
    /// 受信したメッセージは `dispatchInbox` が宛先解決 → Claude セッションへ本文を送信する。
    /// startHandoff と同じ「ローカルキャプチャ → callback」パターン。
    private func startInbox() {
        guard let projectRoot = workspace.projectRoot else { return }
        let store = companionStore
        let reg = registry
        let lay = layout
        let speech = speechState
        inboxWatcher.onMessage = { message, url in
            Self.dispatchInbox(message, inboxURL: url, companionStore: store, registry: reg, layout: lay, speechState: speech, projectRoot: projectRoot)
        }
        inboxWatcher.onError = { msg in
            NSLog("[Aidea] inbox: \(msg)")
        }
        inboxWatcher.start(projectRoot: projectRoot)
    }

    /// inbox メッセージを宛先 Companion に配送する。
    /// 宛先解決 → 未起動なら Claude セッションを生成・bind → `sendMessageWhenReady(message + 返信不要文言)`。
    /// dispatchScheduledJob / dispatchHandoff と同型。宛先解決は `resolveHandoffTarget` を再利用する。
    /// docs/specs/backchannels/inbox.md
    @MainActor
    private static func dispatchInbox(
        _ message: InboxMessage,
        inboxURL: URL,
        companionStore: CompanionStore,
        registry: SessionRegistry,
        layout: LayoutConfig,
        speechState: SpeechState,
        projectRoot: URL?
    ) {
        guard let index = resolveHandoffTarget(message.to, in: companionStore) else {
            NSLog("[Aidea] inbox 宛先が解決できません: \(describeTarget(message.to)) (\(inboxURL.lastPathComponent))")
            return
        }
        let body = message.message + inboxNoReplySuffix
        let companion = companionStore.companion(forIndex: index)

        // 起動済み → アクティブ化して ready 状態に応じて送信
        if let sessionID = companion.sessionID,
           let session = registry.session(for: sessionID),
           let claudeState = session.state as? ClaudeSessionState {
            registry.activateSession(sessionID)
            claudeState.sendMessageWhenReady(body)
            return
        }

        // 未起動 → 起動してから ready 後に送信
        let instance = layout.nextSessionInstance(of: .claude)
        let session = registry.createSession(tool: .claude, instance: instance)
        if let claudeState = session.state as? ClaudeSessionState {
            claudeState.companionPrompt = CompanionInstructions.startupCommand(for: index, projectRoot: projectRoot)
            claudeState.companionIndex = index
            claudeState.speechQueue = speechState.queue
        }
        companionStore.bind(index: index, sessionID: session.id)
        if let pane = registry.activePane ?? layout.allPanes.first {
            pane.tabs.append(session.id)
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
        }
        if let claudeState = session.state as? ClaudeSessionState {
            claudeState.sendMessageWhenReady(body)
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

    // MARK: - External file open (aidea:// URL scheme)

    /// `aidea://open?path=<encoded_path>` または `file://` URL を受け取り Preview で開く。
    /// Claude Code のトランスクリプトビューア等の外部アプリから呼ばれる。
    private func handleExternalOpen(_ url: URL) {
        if url.isFileURL {
            registry.openPreview(for: url, title: url.lastPathComponent)
        } else if url.scheme == "aidea", url.host == "open",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let path = components.queryItems?.first(where: { $0.name == "path" })?.value {
            let fileURL = URL(fileURLWithPath: path)
            registry.openPreview(for: fileURL, title: fileURL.lastPathComponent)
        } else if url.scheme == "aidea", url.host == "open-workspace",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let path = components.queryItems?.first(where: { $0.name == "path" })?.value {
            // 指定リポジトリを新プロセスで開く (既に開いていれば前面化)。ADR 0030 / multi-instance.md
            WorkspaceLauncher.openInNewProcess(projectRoot: URL(fileURLWithPath: path, isDirectory: true))
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
            // 自プロセスの排他ロックを解放する (次回の同一リポジトリ起動が前面化でなく通常起動できるように)
            if let root = workspace.projectRoot {
                InstanceLock.release(for: root)
            }
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

