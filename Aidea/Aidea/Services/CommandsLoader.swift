//
//  CommandsLoader.swift
//  Aidea
//

import Foundation
import Observation

/// `~/.claude/commands/` と `<project>/.claude/commands/` を走査して Command 一覧を提供するサービス。
@Observable
final class CommandsLoader {
    /// 読み込み済み Command 一覧
    var commands: [Command] = []

    /// 両スコープを走査して commands を更新する。
    func reload() {
        var loaded: [Command] = []
        loaded.append(contentsOf: load(from: ClaudeRoots.userRoot, scope: .user))
        loaded.append(contentsOf: load(from: ClaudeRoots.projectRoot, scope: .project))
        self.commands = loaded.sorted {
            if $0.name == $1.name { return $0.scope == .project }
            return $0.name < $1.name
        }
    }

    /// 指定の `.claude` ルート配下の `commands/*.md` を読み込む。
    private func load(from claudeRoot: URL, scope: ResourceScope) -> [Command] {
        let root = claudeRoot.appending(path: "commands", directoryHint: .isDirectory)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else {
            return []
        }
        var result: [Command] = []
        for file in entries where file.pathExtension == "md" {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let (front, body) = FrontmatterParser.parse(source)
            let baseName = file.deletingPathExtension().lastPathComponent
            // description が無ければ本文の最初の非空行を採用
            let fallbackDescription = body
                .split(separator: "\n")
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map(String.init) ?? ""
            result.append(Command(
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
