//
//  ContentView.swift
//  Aidea
//

import SwiftUI

/// アプリのルート View。4 ペイン構成 (Phase 1: ペイン位置は固定、各ペインは複数 Tab を持てる)。
/// レイアウトは NSSplitViewController ラッパ (`SplitLayoutView`) で構築し、
/// ディバイダ位置は autosaveName 経由で自動保存される。
struct ContentView: View {
    @Environment(WorkspaceState.self) private var workspace
    @Environment(SessionRegistry.self) private var registry
    @Environment(LayoutConfig.self) private var layout

    var body: some View {
        Group {
            if let root = workspace.projectRoot {
                SplitLayoutView(
                    layout: layout,
                    workspace: workspace,
                    registry: registry
                )
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
