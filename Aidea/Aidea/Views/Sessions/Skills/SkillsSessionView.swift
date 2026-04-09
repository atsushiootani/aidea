//
//  SkillsSessionView.swift
//  Aidea
//

import SwiftUI

/// Skills Session の SwiftUI View。SkillsSessionState を参照する。
struct SkillsSessionView: View {
    @Bindable var state: SkillsSessionState
    @Environment(WorkspaceState.self) private var workspace

    /// Skill 一覧をピリオド/ハイフン区切りでグループ化したリスト。
    private var groups: [(key: String, items: [Skill])] {
        let dict = Dictionary(grouping: state.loader.skills) { skill -> String in
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
        List(selection: $state.selection) {
            ForEach(groups, id: \.key) { group in
                if group.items.count == 1, group.items[0].name == group.key {
                    skillRow(group.items[0])
                } else {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { state.expanded.contains(group.key) },
                            set: { isOpen in
                                if isOpen { state.expanded.insert(group.key) }
                                else { state.expanded.remove(group.key) }
                            }
                        )
                    ) {
                        ForEach(group.items) { skill in
                            skillRow(skill)
                        }
                    } label: {
                        Text(group.key).font(.headline)
                    }
                    .disclosureGroupStyle(TriangleDisclosureStyle())
                }
            }
        }
        .onAppear { state.loader.reload(projectRoot: workspace.projectRoot) }
        .onChange(of: workspace.projectRoot) { _, newValue in
            state.loader.reload(projectRoot: newValue)
        }
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
