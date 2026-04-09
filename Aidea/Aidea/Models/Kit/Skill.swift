//
//  Skill.swift
//  Aidea
//

import Foundation

/// Skill / Command の取得元スコープ
enum ResourceScope: String {
    case user    // ~/.claude/ 配下
    case project // <project>/.claude/ 配下

    /// サイドバーに表示するタグ文字列
    var label: String {
        switch self {
        case .user:    return "USER"
        case .project: return "PROJECT"
        }
    }
}

/// `~/.claude/skills/<name>/SKILL.md` または `<project>/.claude/skills/<name>/SKILL.md` 1件分を表すモデル。
struct Skill: Identifiable, Hashable {
    let id: String          // "<scope>:<dirname>" で一意化
    let name: String        // frontmatter の name (なければディレクトリ名)
    let description: String // frontmatter の description
    let path: URL           // SKILL.md の絶対パス
    let scope: ResourceScope
}
