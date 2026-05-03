//
//  McpLoader.swift
//  Aidea
//

import Foundation
import Observation

/// `~/.claude.json` の mcpServers エントリを読み込んで MCP サーバー一覧を提供するサービス。
@Observable
final class McpLoader {
    /// 読み込み済み MCP サーバー一覧
    var servers: [McpServer] = []

    /// `~/.claude.json` をパースして servers を更新する。
    func reload() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configFile = home.appending(path: ".claude.json")

        guard let data = try? Data(contentsOf: configFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mcpServers = json["mcpServers"] as? [String: Any] else {
            self.servers = []
            return
        }

        var loaded: [McpServer] = []
        for (name, raw) in mcpServers {
            guard let entry = raw as? [String: Any] else { continue }
            let command = entry["command"] as? String ?? ""
            let args = entry["args"] as? [String] ?? []
            loaded.append(McpServer(id: name, name: name, command: command, args: args))
        }
        // 共通ソート規約: docs/specs/aspects/sort-order.md
        self.servers = loaded.sorted { $0.name.naturalAscending($1.name) }
    }
}
