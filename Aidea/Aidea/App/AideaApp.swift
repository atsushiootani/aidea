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

    init() {
        let ws = WorkspaceState()
        let lay = LayoutConfig()
        let reg = SessionRegistry(workspace: ws, layout: lay)
        let manager = WorkspaceSnapshotManager()

        // 起動時にスナップショットがあれば適用、無ければ既定のアクティブ Session を設定
        if let snapshot = manager.load() {
            manager.apply(snapshot, to: lay, registry: reg)
        } else {
            reg.activeSessionID = lay.allPanes.first?.activeSessionID
        }

        _workspace = State(initialValue: ws)
        _layout = State(initialValue: lay)
        _registry = State(initialValue: reg)
        _snapshotManager = State(initialValue: manager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workspace)
                .environment(registry)
                .environment(layout)
                .onAppear {
                    registerTerminationObserver()
                    registerKeyEventMonitor()
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
                .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            Button("上下に分割") { splitCurrent(axis: .vertical) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
        }
    }

    /// ツール切替メニュー
    @CommandsBuilder
    private var toolMenu: some Commands {
        CommandMenu("ツール") {
            Button("Filer") { focusTool(.filer) }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Kit") { focusTool(.kit) }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Terminal") { focusTool(.terminal) }
                .keyboardShortcut("8", modifiers: [.command])
            Button("Web") { focusTool(.web) }
                .keyboardShortcut("9", modifiers: [.command])
            Button("Preview") { focusTool(.preview) }
                .keyboardShortcut("0", modifiers: [.command])
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

    /// Cmd+T: タブの `+` ボタンと同じ NSMenu を現在位置にポップアップ表示する
    private func newTabWithPicker() {
        guard let pane = currentPane() else { return }
        let lay = layout
        let reg = registry
        let available = Tool.allCases.filter { tool in
            if tool == .filer {
                return !lay.allPanes.contains { $0.tabs.contains { $0.tool == .filer } }
            }
            return true
        }
        let menu = NSMenu()
        for tool in available {
            let item = ClosureMenuItem(
                title: tool.displayName,
                image: NSImage(systemSymbolName: tool.systemImageName, accessibilityDescription: nil)
            ) {
                let instance = lay.nextSessionInstance(of: tool)
                let id = SessionID(tool, instance: instance)
                pane.tabs.append(id)
                pane.activeIndex = pane.tabs.count - 1
                reg.activeSessionID = id
            }
            menu.addItem(item)
        }
        // 現在のマウス位置にスクリーン座標で表示
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    /// Cmd+W: 現在アクティブなタブを閉じる。全タブ消滅時はペインも削除。
    private func closeCurrentTab() {
        guard let activeID = registry.activeSessionID,
              let pane = layout.allPanes.first(where: { $0.tabs.contains(activeID) }),
              let index = pane.tabs.firstIndex(of: activeID) else { return }
        pane.tabs.remove(at: index)
        if pane.activeIndex >= pane.tabs.count {
            pane.activeIndex = max(0, pane.tabs.count - 1)
        }
        registry.activeSessionID = pane.activeSessionID

        if pane.tabs.isEmpty, let node = leafNode(for: pane) {
            DispatchQueue.main.async {
                layout.removeLeaf(node)
                if let firstPane = layout.allPanes.first {
                    registry.activeSessionID = firstPane.activeSessionID
                }
            }
        }
    }

    /// Cmd+Shift+[ / ] : 現在ペイン内でタブを左右に移動 (ラップ)。
    /// SwiftUI の update サイクルと競合しないよう次 runloop に遅延する。
    private func moveTab(offset: Int) {
        let lay = layout
        let reg = registry
        DispatchQueue.main.async {
            guard let activeID = reg.activeSessionID,
                  let pane = lay.allPanes.first(where: { $0.tabs.contains(activeID) }),
                  !pane.tabs.isEmpty else { return }
            let count = pane.tabs.count
            let newIndex = ((pane.activeIndex + offset) % count + count) % count
            pane.activeIndex = newIndex
            reg.activeSessionID = pane.tabs[newIndex]
        }
    }

    /// Cmd+[ / ] : ペイン間をラップで移動。移動先ペインの現在タブをアクティブにする。
    private func movePane(offset: Int) {
        let lay = layout
        let reg = registry
        DispatchQueue.main.async {
            let panes = lay.allPanes
            guard !panes.isEmpty else { return }
            let currentIndex: Int
            if let activeID = reg.activeSessionID,
               let idx = panes.firstIndex(where: { $0.tabs.contains(activeID) }) {
                currentIndex = idx
            } else {
                currentIndex = 0
            }
            let newIndex = ((currentIndex + offset) % panes.count + panes.count) % panes.count
            let targetPane = panes[newIndex]
            // 移動先ペインの activeIndex が不正なら先頭に補正
            if targetPane.activeIndex < 0 || targetPane.activeIndex >= targetPane.tabs.count {
                if !targetPane.tabs.isEmpty {
                    targetPane.activeIndex = 0
                }
            }
            reg.activeSessionID = targetPane.activeSessionID
        }
    }

    /// Cmd+Shift+↓ / → : 現在のペインを分割し、新しく作られたペインのタブを active にする
    private func splitCurrent(axis: LayoutNode.Axis) {
        guard let pane = currentPane(), let node = leafNode(for: pane) else { return }
        DispatchQueue.main.async {
            if let newPane = layout.splitLeaf(node, axis: axis) {
                registry.activeSessionID = newPane.activeSessionID
            }
        }
    }

    /// Cmd+1..0 : 指定 Tool のタブへフォーカス。既にその Tool がアクティブなら次のインスタンスへ循環。
    private func focusTool(_ tool: Tool) {
        let matches: [(pane: Pane, id: SessionID)] = layout.allPanes.flatMap { pane in
            pane.tabs.filter { $0.tool == tool }.map { (pane, $0) }
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
        if let tabIndex = target.pane.tabs.firstIndex(of: target.id) {
            target.pane.activeIndex = tabIndex
        }
        registry.activeSessionID = target.id
    }

    // MARK: - Helpers

    /// 現在アクティブな Session が属する Pane を返す (無ければ最初のペイン)
    private func currentPane() -> Pane? {
        if let activeID = registry.activeSessionID,
           let pane = layout.allPanes.first(where: { $0.tabs.contains(activeID) }) {
            return pane
        }
        return layout.allPanes.first
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
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.shift),
                  !event.modifierFlags.contains(.option),
                  !event.modifierFlags.contains(.control) else {
                return event
            }
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if chars == "w" {
                Self.closeCurrentTabStatic(layout: layout, registry: registry)
                return nil
            }
            return event
        }
    }

    /// closeCurrentTab のスタティックヘルパ (NSEvent 監視クロージャから呼ぶため)
    private static func closeCurrentTabStatic(layout: LayoutConfig, registry: SessionRegistry) {
        guard let activeID = registry.activeSessionID,
              let pane = layout.allPanes.first(where: { $0.tabs.contains(activeID) }),
              let index = pane.tabs.firstIndex(of: activeID) else { return }
        pane.tabs.remove(at: index)
        if pane.activeIndex >= pane.tabs.count {
            pane.activeIndex = max(0, pane.tabs.count - 1)
        }
        registry.activeSessionID = pane.activeSessionID

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
                        registry.activeSessionID = firstPane.activeSessionID
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
        let saveAction = {
            manager.save(layout: layout, registry: registry)
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

/// クロージャを保持する NSMenuItem。Cmd+T のツール選択メニュー等で使う。
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, image: NSImage?, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
        self.image = image
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func invoke() {
        handler()
    }
}

