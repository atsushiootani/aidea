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

    /// ワーキングツリーの変更行数統計 (numstat) — staged + unstaged 合算
    static func numstat(cwd: URL) throws -> String {
        var result = ""
        result += try run(["diff", "--numstat"], cwd: cwd)
        result += try run(["diff", "--cached", "--numstat"], cwd: cwd)
        return result
    }

    /// ステージ済みの変更行数統計 (numstat)
    static func numstatStaged(cwd: URL) throws -> String {
        try run(["diff", "--cached", "--numstat"], cwd: cwd)
    }

    /// 未ステージの変更行数統計 (numstat)
    static func numstatUnstaged(cwd: URL) throws -> String {
        try run(["diff", "--numstat"], cwd: cwd)
    }

    /// main との変更行数統計 (numstat)
    static func numstatMain(cwd: URL) throws -> String {
        try run(["diff", "main...HEAD", "--numstat"], cwd: cwd)
    }

    /// ワーキングツリーの全 diff (staged + unstaged + untracked)。Git パネルと同じアルファベット順で返す。
    static func diffAll(cwd: URL) throws -> String {
        var result = ""
        // staged
        let staged = try run(["diff", "--cached"], cwd: cwd)
        if !staged.isEmpty { result += staged }
        // unstaged
        let unstaged = try run(["diff"], cwd: cwd)
        if !unstaged.isEmpty { result += unstaged }
        // untracked: 空ファイルとの diff を生成
        let untrackedFiles = try untrackedFiles(cwd: cwd)
        for line in untrackedFiles.split(separator: "\n") {
            let file = String(line)
            let diff = try run(["diff", "--no-index", "--", "/dev/null", file], cwd: cwd)
            if !diff.isEmpty { result += diff }
        }
        return sortDiffByPath(result)
    }

    /// diff 文字列内のファイルセクションをパスのアルファベット順に並び替える。
    /// Git パネル (GitSessionState) のツリーと表示順を揃えるために使う。
    /// 同一パスに staged/unstaged の 2 セクションがある場合は staged を先に保つ (安定ソート)。
    private static func sortDiffByPath(_ diff: String) -> String {
        guard diff.contains("diff --git ") else { return diff }

        var sections: [(path: String, lines: [String])] = []
        var currentPath = ""
        var currentLines: [String] = []

        for line in diff.components(separatedBy: "\n") {
            if line.hasPrefix("diff --git ") {
                if !currentPath.isEmpty {
                    var trimmed = currentLines
                    while trimmed.last == "" { trimmed.removeLast() }
                    sections.append((currentPath, trimmed))
                }
                // "diff --git a/... b/<path>" の b/ 以降をソートキーに (最後の " b/" を使う)
                if let range = line.range(of: " b/", options: .backwards) {
                    currentPath = String(line[range.upperBound...])
                } else {
                    currentPath = line
                }
                currentLines = [line]
            } else {
                currentLines.append(line)
            }
        }
        if !currentPath.isEmpty {
            var trimmed = currentLines
            while trimmed.last == "" { trimmed.removeLast() }
            sections.append((currentPath, trimmed))
        }

        sections.sort { $0.path < $1.path }

        var result = sections.map { $0.lines.joined(separator: "\n") }.joined(separator: "\n")
        result += "\n"
        return result
    }

    /// main との全 diff。Git パネルと同じアルファベット順で返す。
    static func diffMain(cwd: URL) throws -> String {
        let diff = try run(["diff", "main...HEAD"], cwd: cwd)
        return sortDiffByPath(diff)
    }

    /// ワーキングツリーの変更ファイル一覧 (unstaged)
    static func diffNameStatus(cwd: URL) throws -> String {
        try run(["diff", "--name-status"], cwd: cwd)
    }

    /// 現在のブランチ名を取得する
    static func currentBranch(cwd: URL) throws -> String {
        try run(["rev-parse", "--abbrev-ref", "HEAD"], cwd: cwd).trimmingCharacters(in: .whitespacesAndNewlines)
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
