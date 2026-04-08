//
//  SkillsListView.swift
//  Aidea
//

import SwiftUI

/// `~/.claude/skills/` の Skill 一覧をサイドバーに表示する View。
struct SkillsListView: View {
    @State private var loader = SkillsLoader()
    @State private var selection: Skill.ID?

    var body: some View {
        List(loader.skills, selection: $selection) { skill in
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name).font(.headline)
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .tag(skill.id)
        }
        .navigationTitle("Skills")
        .onAppear { loader.reload() }
    }
}
