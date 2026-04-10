//
//  GitService.swift
//  Aidea
//

import Foundation

/// Process で git コマンドを実行するヘルパ。
enum GitService {

    /// git コマンドを実行して標準出力を返す
    static func run(_ args: [String], cwd: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = cwd
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// ワーキングツリーの変更ファイル一覧 (unstaged)
    static func diffNameStatus(cwd: URL) throws -> String {
        try run(["diff", "--name-status"], cwd: cwd)
    }

    /// ステージ済みの変更ファイル一覧 (staged)
    static func diffCachedNameStatus(cwd: URL) throws -> String {
        try run(["diff", "--cached", "--name-status"], cwd: cwd)
    }

    /// 未追跡ファイル一覧 (git ls-files --others --exclude-standard)
    static func untrackedFiles(cwd: URL) throws -> String {
        try run(["ls-files", "--others", "--exclude-standard"], cwd: cwd)
    }

    /// main ブランチとの差分ファイル一覧 (name-status)
    static func diffMainNameStatus(cwd: URL) throws -> String {
        try run(["diff", "main...HEAD", "--name-status"], cwd: cwd)
    }

    /// 指定ファイルの diff (unstaged, unified format)
    static func diffFile(_ file: String, cwd: URL) throws -> String {
        try run(["diff", "--", file], cwd: cwd)
    }

    /// 指定ファイルの diff (staged, unified format)
    static func diffCachedFile(_ file: String, cwd: URL) throws -> String {
        try run(["diff", "--cached", "--", file], cwd: cwd)
    }

    /// main との指定ファイルの diff
    static func diffMainFile(_ file: String, cwd: URL) throws -> String {
        try run(["diff", "main...HEAD", "--", file], cwd: cwd)
    }

    /// 未追跡ファイルの diff (空ファイルとの比較)
    static func diffUntracked(_ file: String, cwd: URL) throws -> String {
        // --no-index は差分があると exit code 1 を返すので Process を直接使う
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "--no-index", "--", "/dev/null", file]
        process.currentDirectoryURL = cwd
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// パッチを逆適用 (discard)
    static func applyReverse(patch: String, cwd: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["apply", "--reverse"]
        process.currentDirectoryURL = cwd
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        inputPipe.fileHandleForWriting.write(patch.data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw GitError.applyFailed(output)
        }
    }
}

enum GitError: LocalizedError {
    case applyFailed(String)
    var errorDescription: String? {
        switch self {
        case .applyFailed(let msg): return "git apply に失敗しました: \(msg)"
        }
    }
}
