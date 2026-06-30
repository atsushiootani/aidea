//
//  RemindContent.swift
//  Aidea
//

import Foundation

/// remind ファイル本文の分解ロジック。
/// speech ファイル形式 (1 行目 = 任意の speaker ID + 本文) に、ウィジェット表示用の
/// `表示:` 行を加えた拡張フォーマットを扱う。
/// docs/specs/backchannels/remind.md 参照。
enum RemindContent {
    /// 表示文行のマーカー (半角コロン / 全角コロンの両方を許容)
    private static let displayMarkers = ["表示:", "表示："]

    /// remind ファイル本文を (speakerId, speechText, displayText) に分解する。
    /// - speakerId: 1 行目が数値のみのとき (speech と同じ後方互換ルール)
    /// - displayText: `表示:` で始まる最初の行の値 (無ければ nil)
    /// - speechText: speaker ID 行・表示文行を除いた残り (読み上げ本文)
    static func parse(_ content: String) -> (speakerId: Int?, speechText: String, displayText: String?) {
        var lines = content.components(separatedBy: .newlines)

        // 1 行目が数値のみなら speaker ID として切り出す (speech と同じ)
        var speakerId: Int?
        if let first = lines.first, let id = Int(first.trimmingCharacters(in: .whitespaces)) {
            speakerId = id
            lines.removeFirst()
        }

        // `表示:` 行は最初の 1 件だけを表示文として採用し、残りを読み上げ本文にする
        var displayText: String?
        var bodyLines: [String] = []
        for line in lines {
            if displayText == nil, let value = displayValue(from: line) {
                displayText = value
            } else {
                bodyLines.append(line)
            }
        }

        let speechText = bodyLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let display = displayText?.trimmingCharacters(in: .whitespaces)
        return (speakerId, speechText, (display?.isEmpty == false) ? display : nil)
    }

    /// 行が表示文マーカーで始まればマーカー以降をトリムして返す。そうでなければ nil。
    private static func displayValue(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for marker in displayMarkers where trimmed.hasPrefix(marker) {
            return String(trimmed.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}
