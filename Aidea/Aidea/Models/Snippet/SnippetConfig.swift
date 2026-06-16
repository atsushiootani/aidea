//
//  SnippetConfig.swift
//  Aidea
//

import Foundation

/// `.aidea/config/snippets.json` のルート表現。ユーザが宣言的に編集する設定。
/// 各スニペットは name + command の最小構成で、Terminal セッションへ即時送信する。
/// docs/specs/widgets/snippets.md 参照。
struct SnippetConfig: Codable {
    var snippets: [Snippet] = []

    struct Snippet: Codable, Identifiable, Equatable {
        let id: String
        var name: String
        var command: String
        var enabled: Bool?

        var displayName: String { name }
        var isEnabled: Bool { enabled ?? true }

        var isValid: Bool { validationError == nil }

        var validationError: String? {
            if id.trimmingCharacters(in: .whitespaces).isEmpty { return "id が空" }
            if name.trimmingCharacters(in: .whitespaces).isEmpty { return "name が空" }
            if command.trimmingCharacters(in: .whitespaces).isEmpty { return "command が空" }
            return nil
        }

        init(id: String, name: String, command: String, enabled: Bool? = nil) {
            self.id = id
            self.name = name
            self.command = command
            self.enabled = enabled
        }
    }

    func validSnippets() -> [Snippet] {
        var seen = Set<String>()
        var result: [Snippet] = []
        for snippet in snippets {
            if let error = snippet.validationError {
                NSLog("[Aidea] snippet skipped (\(snippet.id)): \(error)")
                continue
            }
            if seen.contains(snippet.id) {
                NSLog("[Aidea] snippet skipped: id 重複 \"\(snippet.id)\"")
                continue
            }
            seen.insert(snippet.id)
            result.append(snippet)
        }
        return result
    }
}
