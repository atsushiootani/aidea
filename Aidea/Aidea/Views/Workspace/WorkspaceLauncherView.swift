//
//  WorkspaceLauncherView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// 最近開いたリポジトリ (MRU) を選ばせるランチャー画面。
/// 選択時の挙動 (新プロセスで開いて自分は終了するか、現プロセスを継続するか) は呼び出し側が
/// `onSelect` で決める。素起動時は WindowGroup 直下に、メニューからは sheet として表示する。
/// 詳細: docs/specs/window/multi-instance.md / ADR 0030
struct WorkspaceLauncherView: View {
    /// リポジトリが選ばれたときに呼ぶ (新プロセス起動・終了/継続の判断は呼び出し側)
    let onSelect: (URL) -> Void
    @State private var recents: [URL] = RecentProjectsStore.list()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ワークスペースを開く")
                .font(.headline)

            if recents.isEmpty {
                Spacer()
                Text("最近開いたワークスペースはありません")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                List(recents, id: \.self) { url in
                    Button {
                        onSelect(url)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(url.lastPathComponent)
                                .font(.body)
                            Text(url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }

            Button("ワークスペースを開く...") {
                chooseDirectory()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 320, height: 420)
    }

    /// ディレクトリ選択ダイアログを出し、選ばれたリポジトリを onSelect に渡す。
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "開く"
        panel.message = "開くプロジェクトルートを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }
    }
}
