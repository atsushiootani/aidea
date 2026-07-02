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

    /// スニペットの既定送信先。nil (省略) はアクティブ端末扱い。詳細: ADR 0034。
    enum Destination: Equatable {
        /// タブ名指定 (無ければその名前で新規作成)
        case tab(title: String)
        /// 常に新規タブ
        case new
    }

    /// 有効/無効の概念は持たない (常に有効、issue #247)。
    /// 旧フォーマットの `enabled` キーは JSONDecoder が未知キーとして読み飛ばす (後方互換)。
    struct Snippet: Codable, Identifiable, Equatable {
        let id: String
        var name: String
        var command: String
        /// 既定送信先。nil = アクティブ端末 (アクティブが Terminal → そこ / 無ければ最初の Terminal / 無ければ新規)。
        var destination: Destination?

        var displayName: String { name }

        var isValid: Bool { validationError == nil }

        var validationError: String? {
            if id.trimmingCharacters(in: .whitespaces).isEmpty { return "id が空" }
            if name.trimmingCharacters(in: .whitespaces).isEmpty { return "name が空" }
            if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "command が空" }
            return nil
        }

        init(id: String, name: String, command: String, destination: Destination? = nil) {
            self.id = id
            self.name = name
            self.command = command
            self.destination = destination
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

// MARK: - Destination の Codable (タグ付きユニオン: type フィールドで分岐)

extension SnippetConfig.Destination: Codable {
    private enum CodingKeys: String, CodingKey { case type, title }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "tab":
            let title = try c.decode(String.self, forKey: .title)
            self = .tab(title: title)
        case "new":
            self = .new
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "未知の destination type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .tab(let title):
            try c.encode("tab", forKey: .type)
            try c.encode(title, forKey: .title)
        case .new:
            try c.encode("new", forKey: .type)
        }
    }
}
