//
//  SkillsLoader.swift
//  Aidea
//

import Foundation
import Observation

/// `~/.claude/skills/` と `<projectRoot>/.claude/skills/` を走査して Skill 一覧を提供するサービス。
@Observable
final class SkillsLoader {
    /// 読み込み済み Skill 一覧
    var skills: [Skill] = []

    /// 両スコープを走査して skills を更新する。projectRoot が nil なら user スコープのみ。
    func reload(projectRoot: URL?) {
        let userRoot = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude", directoryHint: .isDirectory)
        var loaded: [Skill] = []
        loaded.append(contentsOf: load(from: userRoot, scope: .user))
        if let projectRoot = projectRoot {
            let projectClaude = projectRoot.appending(path: ".claude", directoryHint: .isDirectory)
            loaded.append(contentsOf: load(from: projectClaude, scope: .project))
        }
        // 共通ソート規約: docs/specs/aspects/sort-order.md
        // 同名タイブレークでは PROJECT を前に置く (PROJECT が USER を上書きする関係性を可視化)
        self.skills = loaded.sorted {
            if $0.name == $1.name { return $0.scope == .project }
            return $0.name.naturalAscending($1.name)
        }
    }

    /// 指定の `.claude` ルート配下の `skills/*/SKILL.md` を読み込む。
    private func load(from claudeRoot: URL, scope: ResourceScope) -> [Skill] {
        let root = claudeRoot.appending(path: "skills", directoryHint: .isDirectory)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }
        var result: [Skill] = []
        for dir in entries {
            let skillFile = dir.appending(path: "SKILL.md")
            guard let source = try? String(contentsOf: skillFile, encoding: .utf8) else { continue }
            let (front, _) = FrontmatterParser.parse(source)
            let dirName = dir.lastPathComponent
            result.append(Skill(
                id: "\(scope.rawValue):\(dirName)",
                name: front["name"] ?? dirName,
                description: front["description"] ?? "",
                path: skillFile,
                scope: scope
            ))
        }
        return result
    }
}
