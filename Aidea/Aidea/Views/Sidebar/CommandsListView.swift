//
//  CommandsListView.swift
//  Aidea
//

import SwiftUI

/// `~/.claude/commands/` の Command 一覧をサイドバーに表示する View。
struct CommandsListView: View {
    @State private var loader = CommandsLoader()
    @State private var selection: Command.ID?

    var body: some View {
        List(loader.commands, selection: $selection) { command in
            VStack(alignment: .leading, spacing: 2) {
                Text(command.name).font(.headline)
                Text(command.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .tag(command.id)
        }
        .navigationTitle("Commands")
        .onAppear { loader.reload() }
    }
}
