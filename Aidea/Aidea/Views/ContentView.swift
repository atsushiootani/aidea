//
//  ContentView.swift
//  Aidea
//

import SwiftUI

/// アプリのルート View。3 ペイン (左サイドバー + 中央ターミナル + 右 WebView) を構成する。
struct ContentView: View {
    /// サイドバーで選択中のセクション
    @State private var section: SidebarSection = .skills

    var body: some View {
        NavigationSplitView {
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
            .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } content: {
            // 中央: ターミナル
            TerminalView()
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        } detail: {
            // 右: WebView
            WebView(url: URL(string: "https://www.apple.com")!)
        }
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
