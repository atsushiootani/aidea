//
//  CommandsLoader.swift
//  Aidea
//

import Foundation
import Observation

/// `~/.claude/commands/` と `<projectRoot>/.claude/commands/` を走査して Command 一覧を提供するサービス。
@Observable
final class CommandsLoader {
    /// 読み込み済み Command 一覧
    var commands: [Command] = []

    /// 両スコープを走査して commands を更新する。projectRoot が nil なら user スコープのみ。
    func reload(projectRoot: URL?) {
        let userRoot = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude", directoryHint: .isDirectory)
        var loaded: [Command] = []
        loaded.append(contentsOf: load(from: userRoot, scope: .user))
        if let projectRoot = projectRoot {
            let projectClaude = projectRoot.appending(path: ".claude", directoryHint: .isDirectory)
            loaded.append(contentsOf: load(from: projectClaude, scope: .project))
        }
        // 共通ソート規約: docs/specs/aspects/sort-order.md
        // 同名タイブレークでは PROJECT を前に置く (PROJECT が USER を上書きする関係性を可視化)
        self.commands = loaded.sorted {
            if $0.name == $1.name { return $0.scope == .project }
            return $0.name.naturalAscending($1.name)
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
