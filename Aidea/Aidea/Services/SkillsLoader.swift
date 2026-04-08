//
//  SkillsLoader.swift
//  Aidea
//

import Foundation
import Observation

/// `~/.claude/skills/*/SKILL.md` を走査して Skill 一覧を提供するサービス。
@Observable
final class SkillsLoader {
    /// 読み込み済み Skill 一覧
    var skills: [Skill] = []

    /// `~/.claude/skills/` 配下を走査して skills を更新する。
    func reload() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = home.appending(path: ".claude/skills", directoryHint: .isDirectory)

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            self.skills = []
            return
        }

        var loaded: [Skill] = []
        for dir in entries {
            let skillFile = dir.appending(path: "SKILL.md")
            guard let source = try? String(contentsOf: skillFile, encoding: .utf8) else { continue }
            let (front, _) = FrontmatterParser.parse(source)
            let id = dir.lastPathComponent
            let skill = Skill(
                id: id,
                name: front["name"] ?? id,
                description: front["description"] ?? "",
                path: skillFile
            )
            loaded.append(skill)
        }
        self.skills = loaded.sorted { $0.name < $1.name }
    }
}
