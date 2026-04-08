//
//  ContentView.swift
//  Aidea
//

import SwiftUI

/// アプリのルート View。4 ペイン構成:
///   左上 = ファイラ / 左下 = Skills/Commands/MCPs
///   中央 = ターミナル
///   右   = WebView + ファイルプレビュー切替
struct ContentView: View {
    @Environment(WorkspaceState.self) private var workspace

    var body: some View {
        Group {
            if let root = workspace.projectRoot {
                HSplitView {
                    VSplitView {
                        FileTreeView()
                            .frame(minHeight: 150, idealHeight: 300)
                        SidebarTabsView()
                            .frame(minHeight: 150, idealHeight: 300)
                    }
                    .frame(minWidth: 220, idealWidth: 300)

                    TerminalView(projectRoot: root)
                        .id(root)
                        .frame(minWidth: 400, idealWidth: 600)

                    RightPaneView()
                        .frame(minWidth: 300, idealWidth: 500)
                }
                .frame(minWidth: 1100, minHeight: 600)
                .navigationTitle(root.lastPathComponent)
            } else {
                emptyState
                    .frame(minWidth: 600, minHeight: 400)
                    .navigationTitle("Aidea")
            }
        }
    }

    /// projectRoot が未設定のときに表示するプレースホルダー
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("プロジェクトルートが未設定です")
                .font(.headline)
            Text("メニュー [ファイル → ディレクトリを開く] (⌘O) から選択してください")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environment(WorkspaceState())
}
