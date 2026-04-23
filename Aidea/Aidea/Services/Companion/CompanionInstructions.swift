//
//  CompanionInstructions.swift
//  Aidea
//

import Foundation

/// コンパニオン指示書 (instructions.md) のパス・ロードコマンド文字列を集約するヘルパ。
/// CompanionConfig.initialPrompt 廃止 (ADR 0022) に伴い、
/// 起動時 PTY に送る固定パターン文字列とファイルパスの組み立てを 1 箇所に閉じ込める。
enum CompanionInstructions {
    /// `.aidea/claude/companions/<index>/instructions.md` のベースディレクトリ (projectRoot 相対)
    static let baseDir = ".aidea/claude/companions"
    /// エントリーポイントとなるファイル名
    static let entrypoint = "instructions.md"
    /// 9 個固定のコンパニオン数
    static let companionCount = 9

    /// PTY に send する固定パターン文字列を生成する。
    /// 例: loadCommand(for: 5) → ".aidea/claude/companions/5/instructions.md を読んで従ってね"
    static func loadCommand(for index: Int) -> String {
        "\(baseDir)/\(index)/\(entrypoint) を読んで従ってね"
    }

    /// projectRoot 配下の instructions.md の絶対 URL を返す。
    /// CompanionEditView の「指示書を開く」ボタン等から参照する。
    static func entrypointURL(projectRoot: URL, index: Int) -> URL {
        projectRoot
            .appending(path: baseDir, directoryHint: .isDirectory)
            .appending(path: "\(index)", directoryHint: .isDirectory)
            .appending(path: entrypoint)
    }
}
