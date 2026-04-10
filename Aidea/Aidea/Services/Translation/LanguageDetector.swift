//
//  LanguageDetector.swift
//  Aidea
//

import Foundation
import NaturalLanguage

/// NLLanguageRecognizer を使ってテキストの言語を判定するサービス。
enum LanguageDetector {
    /// テキストの先頭を解析して英語かどうかを判定する
    /// - Parameter text: 判定するテキスト
    /// - Returns: 英語と判定された場合 true
    static func isEnglish(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        // 先頭 1000 文字で判定 (全文は不要)
        let sample = String(text.prefix(1000))
        recognizer.processString(sample)
        return recognizer.dominantLanguage == .english
    }
}
