//
//  DirectorySummaryStore.swift
//  Aidea
//

import Foundation

/// ディレクトリ AI 要約の永続ストア (`.aidea/state/dir-summaries.json`)。
/// projectRoot 相対パス (外なら絶対パス) → 1 行要約 の単純なマップを保持し、
/// 生成のたびに上書き保存する。保存済みエントリは再生成しない (issue #193)。
/// docs/specs/tools/filer.md#showdirectorysummary 参照。
@MainActor
final class DirectorySummaryStore {
    private let fileURL: URL
    private var summaries: [String: String]

    init(projectRoot: URL) {
        fileURL = projectRoot.appending(path: ".aidea/state/dir-summaries.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            summaries = decoded
        } else {
            summaries = [:]
        }
    }

    func summary(for key: String) -> String? {
        summaries[key]
    }

    func set(_ summary: String, for key: String) {
        summaries[key] = summary
        save()
    }

    private func save() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(summaries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
