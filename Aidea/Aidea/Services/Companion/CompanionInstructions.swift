//
//  CompanionInstructions.swift
//  Aidea
//

import Foundation

/// コンパニオン指示書 (instructions.md / agent.md) のパス・起動コマンド文字列を集約するヘルパ。
/// CompanionConfig.initialPrompt 廃止 (ADR 0022) に伴い、
/// 起動時 PTY に送る文字列とファイルパスの組み立てを 1 箇所に閉じ込める。
enum CompanionInstructions {
    /// `.aidea/claude/companions/<index>/` のベースディレクトリ (projectRoot 相対)
    static let baseDir = ".aidea/claude/companions"
    /// 従来の指示書ファイル名
    static let entrypoint = "instructions.md"
    /// エージェント定義ファイル名 (ADR 0029)
    static let agentEntrypoint = "agent.md"
    /// 9 個固定のコンパニオン数
    static let companionCount = 9

    // MARK: - Startup command

    /// コンパニオン起動時に PTY に送るコマンド文字列を返す。
    /// `projectRoot` 配下に `agent.md` が存在する場合はエージェント定義読み込みコマンドを、
    /// 存在しない場合は従来の `instructions.md` 読み込みコマンドにフォールバックする (ADR 0029)。
    static func startupCommand(for index: Int, projectRoot: URL) -> String {
        let agentURL = agentEntrypointURL(projectRoot: projectRoot, index: index)
        if FileManager.default.fileExists(atPath: agentURL.path) {
            return "\(baseDir)/\(index)/\(agentEntrypoint) を読んでエージェントとして振る舞ってね"
        }
        return loadCommand(for: index)
    }

    /// `projectRoot` が nil の場合に `loadCommand` にフォールバックするオーバーロード。
    /// 起動経路で projectRoot が取得できない稀なケース向け。
    static func startupCommand(for index: Int, projectRoot: URL?) -> String {
        guard let projectRoot else { return loadCommand(for: index) }
        return startupCommand(for: index, projectRoot: projectRoot)
    }

    // MARK: - Path helpers

    /// PTY に send する instructions.md 読み込みコマンドを生成する (フォールバック用)。
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

    /// projectRoot 配下の agent.md の絶対 URL を返す。
    static func agentEntrypointURL(projectRoot: URL, index: Int) -> URL {
        projectRoot
            .appending(path: baseDir, directoryHint: .isDirectory)
            .appending(path: "\(index)", directoryHint: .isDirectory)
            .appending(path: agentEntrypoint)
    }
}
