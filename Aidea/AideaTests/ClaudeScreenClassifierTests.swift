//
//  ClaudeScreenClassifierTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// Claude 自動起動の送信可否判定 (issue #295 F7) を検証する。
/// 確認画面では絶対に `.ready` にならないこと、入力欄が見えたときだけ `.ready` になることを確かめる。
/// 仕様: docs/specs/sessions/claude.md#自動起動シーケンス
struct ClaudeScreenClassifierTests {

    @Test("旧形式のフォルダ信頼確認は blocked")
    func blocksLegacyTrustPrompt() {
        let lines = [
            "╭──────────────────────────────╮",
            "│ Do you trust the files in this folder?",
            "│",
            "│ ❯ 1. Yes, proceed",
            "│   2. No, exit",
            "╰──────────────────────────────╯",
            "   Enter to confirm · Esc to exit",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .blocked)
    }

    @Test("新形式のフォルダ信頼確認は blocked")
    func blocksCurrentTrustPrompt() {
        let lines = [
            "Accessing workspace:",
            "/Users/me/repo",
            "Quick safety check: Is this a project you created or one you trust?",
            "❯ 1. Yes, I trust this folder",
            "  2. No, exit",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .blocked)
    }

    @Test("ツール権限確認は blocked")
    func blocksToolPermissionPrompt() {
        let lines = [
            "Bash command",
            "  rm -rf build",
            "Do you want to proceed?",
            "❯ 1. Yes",
            "  2. No",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .blocked)
    }

    @Test("MCP サーバ承認は blocked")
    func blocksMCPServerApproval() {
        let lines = [
            "New MCP server found in .mcp.json: evil",
            "  Use this and all future MCP servers in this project",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .blocked)
    }

    @Test("文言が未知でも番号付き選択メニューは blocked")
    func blocksUnknownNumberedMenu() {
        let lines = [
            "Something new",
            "> 1. Accept",
            "  2. Decline",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .blocked)
    }

    @Test("入力欄と確認画面の兆候が同時にあれば blocked を優先")
    func blockerWinsOverInputLine() {
        let lines = [
            "──────────────",
            "> ",
            "──────────────",
            "  ? for shortcuts",
            "Do you trust the files in this folder?",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .blocked)
    }

    @Test("入力欄のフッタが見えれば ready")
    func readyWithShortcutsFooter() {
        let lines = [
            "✻ Welcome to Claude Code!",
            "",
            "──────────────",
            "> ",
            "──────────────",
            "  ? for shortcuts",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .ready)
    }

    @Test("枠付き入力欄は ready")
    func readyWithBoxedInput() {
        let lines = [
            "╭──────────────╮",
            "│ >            │",
            "╰──────────────╯",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .ready)
    }

    @Test("罫線直下の入力欄は ready")
    func readyWithRuledInput() {
        let lines = [
            "──────────────",
            "❯ ",
            "──────────────",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .ready)
    }

    @Test("シェルのプロンプトだけなら unknown")
    func unknownForShellPrompt() {
        let lines = [
            "Last login: Fri Oct 23 10:00:00 on ttys001",
            "~/repo",
            "❯ claude",
        ]
        #expect(ClaudeScreenClassifier.classify(lines: lines) == .unknown)
    }

    @Test("空画面は unknown")
    func unknownForEmptyScreen() {
        #expect(ClaudeScreenClassifier.classify(lines: []) == .unknown)
        #expect(ClaudeScreenClassifier.classify(lines: ["", "", ""]) == .unknown)
    }
}
