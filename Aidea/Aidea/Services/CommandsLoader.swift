//
//  CommandsLoader.swift
//  Aidea
//

import Foundation
import Observation

/// `~/.claude/commands/*.md` を走査して Command 一覧を提供するサービス。
@Observable
final class CommandsLoader {
    /// 読み込み済み Command 一覧
    var commands: [Command] = []

    /// `~/.claude/commands/` 配下を走査して commands を更新する。
    func reload() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = home.appending(path: ".claude/commands", directoryHint: .isDirectory)

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else {
            self.commands = []
            return
        }

        var loaded: [Command] = []
        for file in entries where file.pathExtension == "md" {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let (front, body) = FrontmatterParser.parse(source)
            let id = file.deletingPathExtension().lastPathComponent
            // description が無ければ本文の最初の非空行を採用
            let fallbackDescription = body
                .split(separator: "\n")
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map(String.init) ?? ""
            let command = Command(
                id: id,
                name: front["name"] ?? id,
                description: front["description"] ?? fallbackDescription,
                path: file
            )
            loaded.append(command)
        }
        self.commands = loaded.sorted { $0.name < $1.name }
    }
}
