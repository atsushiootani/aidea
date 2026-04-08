//
//  SkillsListView.swift
//  Aidea
//

import SwiftUI

/// `~/.claude/skills/` と `<project>/.claude/skills/` の Skill 一覧をグループ化して表示する View。
/// 名前のピリオド区切り先頭部分でグルーピングし、DisclosureGroup で折りたたむ。
struct SkillsListView: View {
    @State private var loader = SkillsLoader()
    @State private var selection: Skill.ID?
    @State private var expanded: Set<String> = []

    /// Skill 一覧を `<prefix>` (ピリオド区切りの先頭) でグループ化したリスト。
    /// グループ名昇順、グループ内も name 昇順。
    private var groups: [(key: String, items: [Skill])] {
        let dict = Dictionary(grouping: loader.skills) { skill -> String in
            // 名前の先頭から . または - までをグループキーにする
            let name = skill.name
            let separators: Set<Character> = [".", "-"]
            if let idx = name.firstIndex(where: { separators.contains($0) }) {
                return String(name[..<idx])
            }
            return name
        }
        return dict.map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(groups, id: \.key) { group in
                if group.items.count == 1, group.items[0].name == group.key {
                    // ピリオドを含まない単独 Skill は DisclosureGroup ではなくそのまま行表示
                    skillRow(group.items[0])
                } else {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expanded.contains(group.key) },
                            set: { isOpen in
                                if isOpen { expanded.insert(group.key) }
                                else { expanded.remove(group.key) }
                            }
                        )
                    ) {
                        ForEach(group.items) { skill in
                            skillRow(skill)
                        }
                    } label: {
                        Text(group.key)
                            .font(.headline)
                    }
                    .disclosureGroupStyle(TriangleDisclosureStyle())
                }
            }
        }
        .onAppear { loader.reload() }
    }

    /// 1 件の Skill 行を生成
    @ViewBuilder
    private func skillRow(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center) {
                Text(skill.name).font(.subheadline)
                Spacer()
                ScopeTagView(scope: skill.scope)
            }
            Text(skill.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .tag(skill.id)
    }
}
