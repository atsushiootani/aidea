//
//  ContentView.swift
//  Aidea
//

import SwiftUI

/// アプリのルート View。3 ペイン (左サイドバー + 中央ターミナル + 右 WebView) を
/// HSplitView で均一に並べる。将来ペイン配置・サイズ変更の機能拡張を前提とした構成。
struct ContentView: View {
    /// サイドバーで選択中のセクション
    @State private var section: SidebarSection = .skills

    var body: some View {
        HSplitView {
            // 左サイドバー: セクション切替 + 一覧
            VStack(spacing: 0) {
                Picker("", selection: $section) {
                    ForEach(SidebarSection.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(8)

                Divider()

                switch section {
                case .skills:   SkillsListView()
                case .commands: CommandsListView()
                case .mcp:      McpListView()
                }
            }
            .frame(minWidth: 220, idealWidth: 280)

            // 中央: ターミナル
            TerminalView()
                .frame(minWidth: 400, idealWidth: 600)

            // 右: WebView
            WebView(url: URL(string: "https://www.apple.com")!)
                .frame(minWidth: 300, idealWidth: 500)
        }
        .frame(minWidth: 1000, minHeight: 600)
        .navigationTitle(currentDirectoryName)
    }

    /// ウィンドウタイトルに表示するカレントディレクトリ名 (プロジェクトルート最終要素)
    private var currentDirectoryName: String {
        URL(fileURLWithPath: "/Users/atsushiotani/PROGRAM/AI/aidea").lastPathComponent
    }
}

/// サイドバーのセクション種別
enum SidebarSection: String, CaseIterable, Identifiable {
    case skills, commands, mcp
    var id: String { rawValue }
    var label: String {
        switch self {
        case .skills:   return "Skills"
        case .commands: return "Commands"
        case .mcp:      return "MCPs"
        }
    }
}

#Preview {
    ContentView()
}
