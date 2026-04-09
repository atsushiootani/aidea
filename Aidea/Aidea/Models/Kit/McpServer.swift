//
//  McpServer.swift
//  Aidea
//

import Foundation

/// `~/.claude.json` の mcpServers エントリ1件分を表すモデル。
struct McpServer: Identifiable, Hashable {
    let id: String           // サーバー名
    let name: String         // 表示名 (= id)
    let command: String      // 実行コマンド (例: "npx")
    let args: [String]       // 引数
}
