//
//  ClaudeTranslator.swift
//  Aidea
//

import Foundation

/// Claude API を使って英語テキストを日本語に翻訳するサービス。
enum ClaudeTranslator {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"
    private static let keychainService = "com.aidea.anthropic-api-key"

    /// API キーを Keychain から取得する
    static var apiKey: String? {
        KeychainHelper.load(service: keychainService)
    }

    /// API キーを Keychain に保存する
    static func setApiKey(_ key: String) {
        KeychainHelper.save(key: key, service: keychainService)
    }

    /// API キーが設定済みか
    static var hasApiKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    /// 英語テキストを日本語に翻訳する
    /// - Parameter text: 翻訳する英語テキスト
    /// - Returns: 日本語に翻訳されたテキスト
    /// - Throws: API キー未設定、ネットワークエラー、API エラー
    static func translate(_ text: String) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw TranslationError.apiKeyNotSet
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 300 // 長いファイルの翻訳に対応 (5 分)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": """
            あなたは翻訳者です。以下の英語テキストを日本語に翻訳してください。
            - Markdown の構造 (見出し、リスト、コードブロック、テーブル、リンク等) はそのまま維持してください
            - コード内の変数名やコマンドは翻訳しないでください
            - 自然で読みやすい日本語にしてください
            - 翻訳結果のみを出力し、説明や注釈は付けないでください
            """,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw TranslationError.apiError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let translatedText = firstBlock["text"] as? String else {
            throw TranslationError.parseError
        }

        return translatedText
    }
}

/// 翻訳時のエラー種別
enum TranslationError: LocalizedError {
    case apiKeyNotSet
    case invalidResponse
    case apiError(statusCode: Int, body: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .apiKeyNotSet:
            return "API キーが設定されていません。メニュー [Aidea → API キー設定] から設定してください。"
        case .invalidResponse:
            return "API からの応答が不正です。"
        case .apiError(let code, let body):
            return "API エラー (\(code)): \(body)"
        case .parseError:
            return "API の応答を解析できませんでした。"
        }
    }
}
