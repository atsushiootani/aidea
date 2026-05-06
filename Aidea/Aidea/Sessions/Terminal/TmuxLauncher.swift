//
//  TmuxLauncher.swift
//  Aidea

import Foundation

/// tmux の有無を検出し、安定したセッション名と起動コマンドを生成するユーティリティ。
/// 仕様: docs/specs/sessions/terminal.md#永続化
enum TmuxLauncher {

    private static let searchPaths = [
        "/opt/homebrew/bin/tmux",
        "/usr/local/bin/tmux",
        "/usr/bin/tmux"
    ]

    /// 実行可能な tmux のパス。見つからなければ nil。
    static var path: String? {
        searchPaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// tmux が利用可能かどうか
    static var isAvailable: Bool { path != nil }

    /// 安定したセッション名を生成する。
    /// 形式: `aidea-<slug>-<hash>-<instance>`
    /// - slug: プロジェクトルートのディレクトリ名を小文字英数・ハイフン正規化したもの
    /// - hash: フルパスの短縮ハッシュ (同名ディレクトリ間の衝突回避)
    static func sessionName(projectRoot: URL?, instance: Int) -> String {
        let rootPath = projectRoot?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
        let slug = slugify(projectRoot?.lastPathComponent ?? "home")
        let hash = shortHash(rootPath)
        return "aidea-\(slug)-\(hash)-\(instance)"
    }

    /// tmux 経由の起動コマンドを返す。同名セッションが存在すれば attach、なければ新規作成。
    static func launchCommand(projectRoot: URL?, instance: Int, tmuxPath: String) -> String {
        let dir = projectRoot?.path ?? FileManager.default.homeDirectoryForCurrentUser.path
        let name = sessionName(projectRoot: projectRoot, instance: instance)
        let escapedDir = shellEscape(dir)
        let escapedName = shellEscape(name)
        return "exec '\(tmuxPath)' new-session -A -s '\(escapedName)' -c '\(escapedDir)'"
    }

    // MARK: - Private helpers

    private static func slugify(_ name: String) -> String {
        var result = ""
        for ch in name.lowercased() {
            if ch.isLetter || ch.isNumber {
                result.append(ch)
            } else if !result.isEmpty && !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "home" : String(trimmed.prefix(24))
    }

    /// djb2 風の 32-bit ハッシュを 5 桁の base-36 文字列にエンコードする
    private static func shortHash(_ string: String) -> String {
        var hash: UInt32 = 5381
        for byte in string.utf8 {
            hash = hash &* 31 &+ UInt32(byte)
        }
        let encoded = String(hash, radix: 36, uppercase: false)
        return String(encoded.prefix(5))
    }

    /// シングルクォートで囲むためにシングルクォートをエスケープする
    private static func shellEscape(_ string: String) -> String {
        string.replacingOccurrences(of: "'", with: "'\\''")
    }
}
