//
//  McpListView.swift
//  Aidea
//

import SwiftUI

/// `~/.claude.json` の mcpServers 一覧をサイドバーに表示する View。
struct McpListView: View {
    @State private var loader = McpLoader()
    @State private var selection: McpServer.ID?

    var body: some View {
        List(loader.servers, selection: $selection) { server in
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name).font(.headline)
                Text("\(server.command) \(server.args.joined(separator: " "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .tag(server.id)
        }
        .navigationTitle("MCP Servers")
        .onAppear { loader.reload() }
    }
}
