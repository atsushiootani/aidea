//
//  AideaApp.swift
//  Aidea
//

import SwiftUI
import AppKit

/// アプリのエントリポイント。WorkspaceState / SessionRegistry / LayoutConfig を生成して
/// 全 View に環境配布し、「ディレクトリを開く」メニューを追加する。
@main
struct AideaApp: App {
    @State private var workspace: WorkspaceState
    @State private var registry: SessionRegistry
    @State private var layout: LayoutConfig

    init() {
        let ws = WorkspaceState()
        let lay = LayoutConfig()
        let reg = SessionRegistry(workspace: ws)
        // 初期のアクティブ Session は左上ペインの先頭タブ
        reg.activeSessionID = lay.topLeft.activeSessionID
        _workspace = State(initialValue: ws)
        _layout = State(initialValue: lay)
        _registry = State(initialValue: reg)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workspace)
                .environment(registry)
                .environment(layout)
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
}
