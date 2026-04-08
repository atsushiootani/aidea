//
//  SidebarTabsView.swift
//  Aidea
//

import SwiftUI

/// 左下ペイン: Skills / Commands / MCPs を Picker で切り替える View。
struct SidebarTabsView: View {
    @State private var section: SidebarSection = .skills

    var body: some View {
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
