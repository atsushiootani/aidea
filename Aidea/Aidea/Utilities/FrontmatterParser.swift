//
//  FrontmatterParser.swift
//  Aidea
//

import Foundation

/// Markdownファイルの先頭に書かれた YAML frontmatter (--- で囲まれたブロック) を抽出するパーサ。
/// 完全な YAML パーサではなく、`key: value` 形式の単純な行のみを対象とする。
enum FrontmatterParser {

    /// パース結果を frontmatter の辞書と本文に分けて返す。
    /// frontmatter が存在しない場合は空辞書と元の文字列をそのまま返す。
    static func parse(_ source: String) -> (frontmatter: [String: String], body: String) {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // 先頭行が "---" でなければ frontmatter なしと判定
        guard let firstLine = lines.first, firstLine.trimmingCharacters(in: .whitespaces) == "---" else {
            return ([:], source)
        }

        // 2行目以降から閉じの "---" を探す
        var frontmatter: [String: String] = [:]
        var closeIndex: Int?
        for index in 1..<lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                closeIndex = index
                break
            }
            // "key: value" を split
            if let colon = lines[index].firstIndex(of: ":") {
                let key = String(lines[index][..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(lines[index][lines[index].index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    frontmatter[key] = value
                }
            }
        }

        // 閉じの "---" が見つからなければ frontmatter として扱わない
        guard let close = closeIndex else {
            return ([:], source)
        }

        let bodyLines = lines[(close + 1)...]
        let body = bodyLines.joined(separator: "\n")
        return (frontmatter, body)
    }
}
