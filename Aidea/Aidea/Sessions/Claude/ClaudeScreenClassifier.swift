//
//  ClaudeScreenClassifier.swift
//  Aidea
//

import Foundation

/// 端末の可視画面テキストから、Claude Code TUI が「自動送信してよい状態」かを判定する。
///
/// 自動起動シーケンスは固定タイマーでキーを送らず、この判定が `.ready` になってから送る
/// (issue #295 F7)。フォルダ信頼・MCP サーバ承認・ツール権限などの確認画面が出ているときに
/// Enter を送ると、ユーザーの代わりに承認してしまうため。
/// 判定は安全側に倒す: 確認画面らしき兆候が 1 つでもあれば `.blocked`、
/// 入力欄が確実に見えるときだけ `.ready`、それ以外は `.unknown` (送らずに待つ)。
/// 仕様: docs/specs/sessions/claude.md#自動起動シーケンス
enum ClaudeScreenClassifier {
    enum State: Equatable {
        /// 入力欄が表示され、確認画面は出ていない
        case ready
        /// 信頼 / 権限などの確認画面が出ている (ユーザーの操作待ち)
        case blocked
        /// まだ判定できない (claude 起動中・シェルのまま等)
        case unknown
    }

    /// 確認画面に出る文言。Claude Code のバージョン差を吸収するため複数持つ (大文字小文字は無視)
    private static let blockerPhrases = [
        "trust the files",
        "trust this folder",
        "one you trust",
        "do you want to",
        "enter to confirm",
        "mcp server",
    ]

    /// 入力欄が空のときのフッタ
    private static let readyFooter = "? for shortcuts"

    static func classify(lines: [String]) -> State {
        let lowered = lines.map { $0.lowercased() }
        if lowered.contains(where: { line in blockerPhrases.contains(where: line.contains) }) {
            return .blocked
        }
        // 選択メニュー (`❯ 1. Yes` 形式) は確認画面の共通形なので文言によらず止める
        if lines.contains(where: isNumberedChoice) {
            return .blocked
        }
        if lowered.contains(where: { $0.contains(readyFooter) }) {
            return .ready
        }
        for (index, line) in lines.enumerated() where isInputLine(line) {
            // シェルのプロンプト (`❯ ` 等) と区別するため、枠付き (`│ > `) か
            // 直上が罫線 (`────`) の入力欄だけを認める
            if line.contains("│") { return .ready }
            if index > 0, isHorizontalRule(lines[index - 1]) { return .ready }
        }
        return .unknown
    }

    /// 枠線を除いた先頭が `>` / `❯` の行 (Claude Code の入力欄)
    private static func isInputLine(_ line: String) -> Bool {
        let body = line.drop(while: { $0 == " " || $0 == "│" })
        guard let first = body.first, first == ">" || first == "❯" else { return false }
        let rest = body.dropFirst()
        return rest.isEmpty || rest.first == " " || rest.first == "\u{00A0}"
    }

    /// `❯ 1.` / `> 2.` のような選択肢カーソル行
    private static func isNumberedChoice(_ line: String) -> Bool {
        let body = line.drop(while: { $0 == " " || $0 == "│" })
        guard let first = body.first, first == ">" || first == "❯" else { return false }
        let rest = body.dropFirst().drop(while: { $0 == " " })
        let digits = rest.prefix(while: \.isNumber)
        return !digits.isEmpty && rest.dropFirst(digits.count).first == "."
    }

    /// `─` だけで構成された罫線行
    private static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 3 && trimmed.allSatisfy { $0 == "─" }
    }
}
