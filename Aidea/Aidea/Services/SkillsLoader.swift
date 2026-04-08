//
//  SkillsLoader.swift
//  Aidea
//

import Foundation
import Observation

/// Skill / Command の取得元となるディレクトリのルートを集約する定数。
enum ClaudeRoots {
    /// ~/.claude
    static var userRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude", directoryHint: .isDirectory)
    }
    /// プロジェクトルート直下の .claude
    /// MEMO: 当面は単一プロジェクトのためハードコード (SPEC.md 将来項目参照)
    static var projectRoot: URL {
        URL(fileURLWithPath: "/Users/atsushiotani/PROGRAM/AI/aidea/.claude", isDirectory: true)
    }
}

/// `~/.claude/skills/` と `<project>/.claude/skills/` を走査して Skill 一覧を提供するサービス。
@Observable
final class SkillsLoader {
    /// 読み込み済み Skill 一覧
    var skills: [Skill] = []

    /// 両スコープを走査して skills を更新する。
    func reload() {
        var loaded: [Skill] = []
        loaded.append(contentsOf: load(from: ClaudeRoots.userRoot, scope: .user))
        loaded.append(contentsOf: load(from: ClaudeRoots.projectRoot, scope: .project))
        self.skills = loaded.sorted {
            // 同名は project を優先表示
            if $0.name == $1.name { return $0.scope == .project }
            return $0.name < $1.name
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
