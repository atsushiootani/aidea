//
//  Skill.swift
//  Aidea
//

import Foundation

/// `~/.claude/skills/<name>/SKILL.md` 1件分を表すモデル。
struct Skill: Identifiable, Hashable {
    let id: String          // ディレクトリ名 (一意)
    let name: String        // frontmatter の name (なければ id)
    let description: String // frontmatter の description
    let path: URL           // SKILL.md の絶対パス
}
