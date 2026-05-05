//
//  TranslationService.swift
//  Aidea
//

import Foundation
import AppKit

/// 翻訳フロー全体を統括するサービス。
/// 言語判定 → キャッシュ確認 → Claude API SSE 翻訳 → キャッシュ保存 → URL 返却。
enum TranslationService {

    /// 翻訳結果のキャッシュ URL を返す。必要なら Claude API で翻訳してキャッシュを作る。
    /// - Parameters:
    ///   - originalURL: 翻訳元の英語ファイル URL
    ///   - projectRoot: プロジェクトルート
    ///   - onProgress: チャンク受信ごとに呼ばれる進捗コールバック (累積文字数)。メインアクターで呼ばれる
    /// - Returns: キャッシュされた日本語訳ファイルの URL
    /// - Throws: API キー未設定、翻訳エラー等
    static func translateIfNeeded(
        originalURL: URL,
        projectRoot: URL,
        onProgress: (@MainActor @Sendable (Int) -> Void)? = nil
    ) async throws -> URL {
        guard let cachedURL = TranslationCache.cachedURL(for: originalURL, projectRoot: projectRoot) else {
            throw TranslationError.invalidResponse
        }

        // キャッシュが新鮮ならそのまま返す
        if TranslationCache.isFresh(original: originalURL, cached: cachedURL) {
            return cachedURL
        }

        // API キー確認 (未設定なら設定ダイアログを表示)
        if !ClaudeTranslator.hasApiKey {
            let keySet = await MainActor.run { showApiKeyDialog() }
            guard keySet else { throw TranslationError.apiKeyNotSet }
        }

        let originalText = try String(contentsOf: originalURL, encoding: .utf8)

        // キャッシュディレクトリを事前作成して FileWatcher が検知できる状態にする
        let cacheDir = cachedURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        var accumulated = ""
        do {
            for try await chunk in ClaudeTranslator.translateStream(originalText) {
                accumulated += chunk
                // 累積テキストをキャッシュに書き込む (FileWatcher が sibling タブを逐次更新)
                try accumulated.write(to: cachedURL, atomically: true, encoding: .utf8)
                if let handler = onProgress {
                    let count = accumulated.count
                    await MainActor.run { handler(count) }
                }
            }
        } catch {
            // 部分的なキャッシュを残さないよう削除する
            try? FileManager.default.removeItem(at: cachedURL)
            throw error
        }

        return cachedURL
    }

    /// API キー設定ダイアログを表示する。設定されたら true を返す。
    @MainActor
    @discardableResult
    static func showApiKeyDialog() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Anthropic API キーの設定"
        alert.informativeText = "翻訳に Claude API を使用します。API キーを入力してください。"
        alert.alertStyle = .informational

        let textField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 350, height: 24))
        textField.placeholderString = "sk-ant-..."
        if let existing = ClaudeTranslator.apiKey {
            textField.stringValue = existing
        }
        alert.accessoryView = textField

        alert.addButton(withTitle: "保存")
        let cancel = alert.addButton(withTitle: "キャンセル")
        cancel.keyEquivalent = "\u{1b}"

        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        let key = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        ClaudeTranslator.setApiKey(key)
        return true
    }
}
