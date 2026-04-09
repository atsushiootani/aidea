//
//  Agent.swift
//  Aidea
//

import Foundation

/// `~/.claude/agents/<name>.md` または `<projectRoot>/.claude/agents/<name>.md` 1件分を表すモデル。
struct Agent: Identifiable, Hashable {
    let id: String          // "<scope>:<filename>" で一意化
    let name: String        // frontmatter の name (なければファイル名)
    let description: String // frontmatter の description (なければ本文先頭行)
    let path: URL           // .md の絶対パス
    let scope: ResourceScope
}
