//
//  ExcludeMatcher.swift
//  Aidea
//

import Foundation

/// Filer の表示・検索からファイル/ディレクトリを除外するための glob パターンマッチャ。
/// パターン形式は `.gitignore` 風 (basename glob / path prefix glob, `*` と `?` のみ対応、照合は `GlobMatcher`)。
/// 詳細仕様は `docs/specs/tools/filer.md#除外ルール` を参照。
struct ExcludeMatcher {
    /// 評価対象の除外パターン一覧 (空文字列は無視)
    let patterns: [String]

    /// 指定の相対パスがいずれかのパターンにマッチするか判定する
    /// - Parameter relativePath: projectRoot からの相対パス (先頭スラッシュ無し)
    func matches(relativePath: String) -> Bool {
        let basename = (relativePath as NSString).lastPathComponent
        for pattern in patterns where !pattern.isEmpty {
            if pattern.contains("/") {
                if GlobMatcher.matchesPathPrefix(pattern: pattern, path: relativePath) { return true }
            } else {
                if GlobMatcher.matches(pattern: pattern, target: basename) { return true }
            }
        }
        return false
    }
}
