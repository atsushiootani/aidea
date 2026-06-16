//
//  SnippetStore.swift
//  Aidea
//

import Foundation

/// `.aidea/config/snippets.json` の読み書きを担う。
/// SchedulerStore と同じ `.prettyPrinted, .sortedKeys` + `.atomic` write パターン。
/// docs/specs/widgets/snippets.md 参照。
struct SnippetStore {
    let projectRoot: URL

    private var configURL: URL {
        projectRoot
            .appending(path: ".aidea", directoryHint: .isDirectory)
            .appending(path: "config", directoryHint: .isDirectory)
            .appending(path: "snippets.json")
    }

    func loadConfig() -> SnippetConfig {
        guard let data = try? Data(contentsOf: configURL) else {
            return SnippetConfig()
        }
        do {
            return try JSONDecoder().decode(SnippetConfig.self, from: data)
        } catch {
            NSLog("[Aidea] snippets config decode failed: \(error.localizedDescription)")
            return SnippetConfig()
        }
    }

    func saveConfig(_ config: SnippetConfig) {
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: .atomic)
        } catch {
            NSLog("[Aidea] snippets config save failed: \(error.localizedDescription)")
        }
    }
}
