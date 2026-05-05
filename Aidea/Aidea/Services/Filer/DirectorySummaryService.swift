//
//  DirectorySummaryService.swift
//  Aidea
//

import Foundation

/// Claude Haiku API を使ってディレクトリの 1 行概要を生成するサービス。
/// 仕様: docs/specs/tools/filer.md#showDirectorySummary
enum DirectorySummaryService {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"
    private static let keychainService = "com.aidea.anthropic-api-key"

    private static let systemPrompt = """
        あなたはファイルシステムのアナリストです。
        与えられたディレクトリ名とその直下のエントリ一覧から、\
        そのディレクトリが何のためのものかを日本語で 1 行（30〜50 字程度）で説明してください。
        説明文のみを出力し、余分な説明や記号は付けないでください。
        """

    static var apiKey: String? {
        KeychainHelper.load(service: keychainService)
    }

    static var hasApiKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    /// ディレクトリの 1 行概要を生成する。
    /// API キー未設定または API エラー時は nil を返す。
    static func generate(directoryURL: URL, children: [String]) async -> String? {
        guard let key = apiKey, !key.isEmpty else { return nil }

        let dirName = directoryURL.lastPathComponent
        let listed = children.prefix(40).joined(separator: "\n")
        let userMessage = """
            ディレクトリ名: \(dirName)
            直下のエントリ:
            \(listed)
            """

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 128,
            "stream": false,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = (json["content"] as? [[String: Any]])?.first,
                  let text = content["text"] as? String else { return nil }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
