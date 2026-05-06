//
//  CompanionInstructions.swift
//  Aidea
//

import Foundation

/// コンパニオン指示書 (instructions.md / agent.md) のパス・ロードコマンド文字列を集約するヘルパ。
/// CompanionConfig.initialPrompt 廃止 (ADR 0022) に伴い、
/// 起動時 PTY に送る固定パターン文字列とファイルパスの組み立てを 1 箇所に閉じ込める。
/// agent.md が存在する場合は ADR 0026 のエージェント定義起動コマンドを返す。
enum CompanionInstructions {
    /// `.aidea/claude/companions/<index>/instructions.md` のベースディレクトリ (projectRoot 相対)
    static let baseDir = ".aidea/claude/companions"
    /// エントリーポイントとなるファイル名
    static let entrypoint = "instructions.md"
    /// エージェント定義ファイル名 (ADR 0026)
    static let agentFileName = "agent.md"
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

    /// projectRoot 配下の agent.md の絶対 URL を返す (ADR 0026)。
    static func agentURL(projectRoot: URL, index: Int) -> URL {
        projectRoot
            .appending(path: baseDir, directoryHint: .isDirectory)
            .appending(path: "\(index)", directoryHint: .isDirectory)
            .appending(path: agentFileName)
    }

    /// agent.md の有無に応じて適切な起動コマンドを返す (ADR 0026)。
    /// agent.md が存在すればエージェント定義読み込みコマンド、
    /// なければ loadCommand(for:) にフォールバック。
    /// projectRoot が nil の場合も loadCommand にフォールバック。
    static func startupCommand(for index: Int, projectRoot: URL?) -> String {
        guard let projectRoot else { return loadCommand(for: index) }
        let agentPath = agentURL(projectRoot: projectRoot, index: index)
        if FileManager.default.fileExists(atPath: agentPath.path) {
            return "\(baseDir)/\(index)/\(agentFileName) を読んで、その定義に従ってエージェントとして動いてね"
        }
        return loadCommand(for: index)
    }
}
