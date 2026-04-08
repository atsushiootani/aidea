//
//  CommandsListView.swift
//  Aidea
//

import SwiftUI

/// `~/.claude/commands/` と `<project>/.claude/commands/` の Command 一覧をグループ化して表示する View。
/// 名前のピリオド区切り先頭部分でグルーピングし、DisclosureGroup で折りたたむ。
struct CommandsListView: View {
    @State private var loader = CommandsLoader()
    @State private var selection: Command.ID?
    @State private var expanded: Set<String> = []

    /// Command 一覧を `<prefix>` (ピリオド区切りの先頭) でグループ化したリスト。
    private var groups: [(key: String, items: [Command])] {
        let dict = Dictionary(grouping: loader.commands) { command -> String in
            // 名前の先頭から . または - までをグループキーにする
            let name = command.name
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
                    commandRow(group.items[0])
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
                        ForEach(group.items) { command in
                            commandRow(command)
                        }
                    } label: {
                        Text(group.key)
                            .font(.headline)
                    }
                    .disclosureGroupStyle(TriangleDisclosureStyle())
                }
            }
        }
        .navigationTitle("Commands")
        .onAppear { loader.reload() }
    }

    /// 1 件の Command 行を生成
    @ViewBuilder
    private func commandRow(_ command: Command) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center) {
                Text(command.name).font(.subheadline)
                Spacer()
                ScopeTagView(scope: command.scope)
            }
            Text(command.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .tag(command.id)
    }
}
