//
//  AideaApp.swift
//  Aidea
//

import SwiftUI
import AppKit

/// アプリのエントリポイント。WorkspaceState / SessionRegistry / LayoutConfig を生成して
/// 全 View に環境配布し、「ディレクトリを開く」メニューを追加する。
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
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("ディレクトリを開く...") {
                    openDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }

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
