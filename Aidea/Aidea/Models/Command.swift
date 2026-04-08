//
//  Command.swift
//  Aidea
//

import Foundation

/// `~/.claude/commands/<name>.md` 1件分を表すモデル。
struct Command: Identifiable, Hashable {
    let id: String          // ファイル名 (拡張子なし)
    let name: String        // frontmatter の name (なければ id)
    let description: String // frontmatter の description (なければ本文先頭行)
    let path: URL           // .md の絶対パス
}
