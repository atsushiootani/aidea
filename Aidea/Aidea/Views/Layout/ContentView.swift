//
//  ContentView.swift
//  Aidea
//

import SwiftUI

/// アプリのルート View。4 ペイン構成 (Phase 1: ペイン位置は固定、各ペインは複数 Tab を持てる)。
struct ContentView: View {
    @Environment(WorkspaceState.self) private var workspace
    @Environment(SessionRegistry.self) private var registry
    @Environment(LayoutConfig.self) private var layout

    var body: some View {
        Group {
            if let root = workspace.projectRoot {
                HSplitView {
                    VSplitView {
                        PaneView(pane: layout.topLeft)
                            .frame(minHeight: 150, idealHeight: 300)
                        PaneView(pane: layout.bottomLeft)
                            .frame(minHeight: 150, idealHeight: 300)
                    }
                    .frame(minWidth: 220, idealWidth: 300)

                    PaneView(pane: layout.center)
                        .id(root)
                        .frame(minWidth: 400, idealWidth: 600)

                    PaneView(pane: layout.right)
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
