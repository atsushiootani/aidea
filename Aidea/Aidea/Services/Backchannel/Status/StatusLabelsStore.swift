//
//  StatusLabelsStore.swift
//  Aidea
//

import Foundation

/// `.aidea/config/status-labels.json` の読み込みを担う。SnippetStore/SchedulerStore と同じ配置規約
/// (`.aidea/config/<name>.json`)。ユーザが手編集する想定のため保存 (write) 機能は持たない。
/// 仕様: docs/specs/backchannels/status.md
struct StatusLabelsStore {
    let projectRoot: URL

    private var configURL: URL {
        projectRoot
            .appending(path: ".aidea", directoryHint: .isDirectory)
            .appending(path: "config", directoryHint: .isDirectory)
            .appending(path: "status-labels.json")
    }

    func loadConfig() -> StatusLabelsConfig {
        guard let data = try? Data(contentsOf: configURL) else {
            return StatusLabelsConfig()
        }
        do {
            return try JSONDecoder().decode(StatusLabelsConfig.self, from: data)
        } catch {
            NSLog("[Aidea] status-labels config decode failed: \(error.localizedDescription)")
            return StatusLabelsConfig()
        }
    }
}
