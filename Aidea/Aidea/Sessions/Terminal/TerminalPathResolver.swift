//
//  TerminalPathResolver.swift
//  Aidea
//

import Foundation

/// ターミナル出力中のファイルパス検出結果。
/// `TerminalPathResolver` が行内のテキストから実在するパスを抽出して返す。
struct TerminalPathMatch: Equatable {
    /// 検出範囲の開始列 (行内 0-based 文字インデックス)
    let startColumn: Int
    /// 検出範囲の終了列 (exclusive)
    let endColumn: Int
    /// regex がマッチしたパス部分の文字列 (`:行数` を含まない)
    let path: String
    /// 行番号 (オプション、`path:42` の `42`)
    let line: Int?
    /// 解決済みの絶対 URL
    let absoluteURL: URL
    /// projectRoot からの相対パス (絶対パスなら絶対パスのまま)。Preview のタブタイトル用
    let displayPath: String
}

/// projectRoot 起点 / プロジェクト内検索フォールバックを含むパス解決結果。
enum FallbackMatchResult {
    case single(TerminalPathMatch)
    case ambiguous([URL])
}

/// 行テキストから ASCII のファイルパスを検出して projectRoot 起点で解決する純関数ヘルパ。
/// SwiftTerm/UI 依存を持たず、Foundation のみで完結する (テスト容易性)。
/// 仕様: docs/specs/tools/terminal.md#ファイルパスのクリック起動-issue-71
enum TerminalPathResolver {
    /// 行内の col 位置に重なるパス候補があれば、実在確認した上で返す。
    /// クリック / ホバー判定の両方で使用する。
    static func match(in line: String, at column: Int, projectRoot: URL?) -> TerminalPathMatch? {
        for candidate in detectCandidates(in: line) {
            if column >= candidate.startColumn && column < candidate.endColumn {
                if let resolved = resolve(candidate: candidate, projectRoot: projectRoot) {
                    return resolved
                }
            }
        }
        return nil
    }

    /// match() と同様だが、projectRoot 起点での解決に失敗した場合は
    /// projectRoot 以下をファイル名一致 / 末尾パス一致でフォールバック検索する。
    /// 仕様: docs/specs/tools/terminal.md#パス解決
    static func matchWithFallback(in line: String, at column: Int, projectRoot: URL?) -> FallbackMatchResult? {
        if let m = match(in: line, at: column, projectRoot: projectRoot) {
            return .single(m)
        }
        guard let root = projectRoot else { return nil }
        guard let candidate = detectCandidates(in: line).first(where: {
            column >= $0.startColumn && column < $0.endColumn
        }) else { return nil }
        let found = searchProject(path: candidate.path, projectRoot: root)
        switch found.count {
        case 0:
            return nil
        case 1:
            let url = found[0]
            let relPath = url.path.hasPrefix(root.path + "/")
                ? String(url.path.dropFirst(root.path.count + 1))
                : url.path
            return .single(TerminalPathMatch(
                startColumn: candidate.startColumn,
                endColumn: candidate.endColumn,
                path: candidate.path,
                line: candidate.line,
                absoluteURL: url,
                displayPath: relPath
            ))
        default:
            return .ambiguous(found)
        }
    }

    /// projectRoot 以下をファイル名一致 / 末尾パス一致で再帰検索する。
    /// 結果は NSCache でキャッシュし、hover 時の繰り返し呼び出しを効率化する。
    /// 隠しファイル (.git 等) と Xcode パッケージは除外する。
    static func searchProject(path: String, projectRoot: URL) -> [URL] {
        let cacheKey = "\(projectRoot.path)|\(path)" as NSString
        if let cached = projectSearchCache.object(forKey: cacheKey) {
            return cached as! [URL]
        }
        let normalized = path.hasPrefix("./") ? String(path.dropFirst(2)) : path
        guard let enumerator = FileManager.default.enumerator(
            at: projectRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            projectSearchCache.setObject([] as NSArray, forKey: cacheKey)
            return []
        }
        var results: [URL] = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            let relativePath = url.path.hasPrefix(projectRoot.path + "/")
                ? String(url.path.dropFirst(projectRoot.path.count + 1))
                : url.path
            if relativePath == normalized || relativePath.hasSuffix("/" + normalized) {
                results.append(url)
            }
        }
        projectSearchCache.setObject(results as NSArray, forKey: cacheKey)
        return results
    }

    /// 行内のすべてのパス候補を実在確認込みで列挙する (デバッグ・将来用)。
    static func detectPaths(in line: String, projectRoot: URL?) -> [TerminalPathMatch] {
        detectCandidates(in: line).compactMap { resolve(candidate: $0, projectRoot: projectRoot) }
    }

    // MARK: - Internal

    /// regex マッチで得られる「パス候補」の生情報 (実在確認前)。
    private struct Candidate {
        let startColumn: Int
        let endColumn: Int
        let path: String
        let line: Int?
    }

    /// 行内のパス候補を regex で抽出する。実在確認は行わない。
    /// - 拡張子末尾 `.<2 文字以上の英数>` を必須とする
    /// - lookbehind/lookahead で path 文字の連続を弾き、語境界を確保する
    private static func detectCandidates(in line: String) -> [Candidate] {
        guard let regex = pathRegex else { return [] }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        var results: [Candidate] = []
        regex.enumerateMatches(in: line, options: [], range: range) { match, _, _ in
            guard let match = match,
                  match.numberOfRanges >= 2 else { return }
            let pathRange = match.range(at: 1)
            guard pathRange.location != NSNotFound else { return }
            let path = nsLine.substring(with: pathRange)

            var line: Int? = nil
            if match.numberOfRanges >= 3 {
                let lineRange = match.range(at: 2)
                if lineRange.location != NSNotFound {
                    line = Int(nsLine.substring(with: lineRange))
                }
            }
            // 全体マッチ範囲 (`path` + 任意の `:行数`) を文字インデックスに変換
            let fullRange = match.range
            let startColumn = nsLine.substring(to: fullRange.location).count
            let endColumn = startColumn + nsLine.substring(with: fullRange).count
            results.append(Candidate(
                startColumn: startColumn,
                endColumn: endColumn,
                path: path,
                line: line
            ))
        }
        return results
    }

    /// 候補を projectRoot 起点で絶対化し、`FileManager.fileExists` で実在確認する。
    /// ディレクトリは除外 (Preview はファイル想定のため)。
    private static func resolve(candidate: Candidate, projectRoot: URL?) -> TerminalPathMatch? {
        let absoluteURL: URL
        let displayPath: String
        if candidate.path.hasPrefix("/") {
            absoluteURL = URL(fileURLWithPath: candidate.path).standardizedFileURL
            displayPath = candidate.path
        } else if let root = projectRoot {
            absoluteURL = root.appendingPathComponent(candidate.path).standardizedFileURL
            displayPath = candidate.path
        } else {
            return nil
        }
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: absoluteURL.path, isDirectory: &isDirectory)
        guard exists, !isDirectory.boolValue else { return nil }
        return TerminalPathMatch(
            startColumn: candidate.startColumn,
            endColumn: candidate.endColumn,
            path: candidate.path,
            line: candidate.line,
            absoluteURL: absoluteURL,
            displayPath: displayPath
        )
    }

    /// パス検出 regex。spec の文字種・拡張子規則を厳密に表す。
    /// - lookbehind `(?<![\\w./\\-])`: 直前が path 文字ではないこと (= 行頭または区切り)
    /// - グループ 1: ASCII 英数 + `.` `_` `-` `/` の連続で、末尾に `.<2文字以上の英数>` 拡張子
    /// - グループ 2 (オプション): `:<整数>` 形式の行番号
    /// - lookahead `(?![\\w./\\-])`: 直後が path 文字でないこと (= 行末または区切り)
    private static let pathRegex: NSRegularExpression? = {
        // NSRegularExpression は Swift Regex と違い、lookbehind/lookahead を ICU で使える
        let pattern = #"(?<![A-Za-z0-9._\-/])([A-Za-z0-9._\-/]+\.[A-Za-z0-9]{2,})(?::([0-9]+))?(?![A-Za-z0-9._\-/])"#
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    private static let projectSearchCache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.countLimit = 200
        return cache
    }()
}
