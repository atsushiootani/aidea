//
//  AgentsLoader.swift
//  Aidea
//

import Foundation
import Observation

/// `~/.claude/agents/` と `<projectRoot>/.claude/agents/` を走査して Agent 一覧を提供するサービス。
@Observable
final class AgentsLoader {
    /// 読み込み済み Agent 一覧
    var agents: [Agent] = []

    /// 両スコープを走査して agents を更新する。projectRoot が nil なら user スコープのみ。
    func reload(projectRoot: URL?) {
        let userRoot = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude", directoryHint: .isDirectory)
        var loaded: [Agent] = []
        loaded.append(contentsOf: load(from: userRoot, scope: .user))
        if let projectRoot = projectRoot {
            let projectClaude = projectRoot.appending(path: ".claude", directoryHint: .isDirectory)
            loaded.append(contentsOf: load(from: projectClaude, scope: .project))
        }
        self.agents = loaded.sorted {
            if $0.name == $1.name { return $0.scope == .project }
            return $0.name < $1.name
        }
    }

    /// 指定の `.claude` ルート配下の `agents/*.md` を読み込む。
    private func load(from claudeRoot: URL, scope: ResourceScope) -> [Agent] {
        let root = claudeRoot.appending(path: "agents", directoryHint: .isDirectory)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else {
            return []
        }
        var result: [Agent] = []
        for file in entries where file.pathExtension == "md" {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let (front, body) = FrontmatterParser.parse(source)
            let baseName = file.deletingPathExtension().lastPathComponent
            let fallbackDescription = body
                .split(separator: "\n")
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map(String.init) ?? ""
            result.append(Agent(
                id: "\(scope.rawValue):\(baseName)",
                name: front["name"] ?? baseName,
                description: front["description"] ?? fallbackDescription,
                path: file,
                scope: scope
            ))
        }
        return result
    }
}
