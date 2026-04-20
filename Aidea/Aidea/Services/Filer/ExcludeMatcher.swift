//
//  ExcludeMatcher.swift
//  Aidea
//

import Foundation

/// Filer の表示・検索からファイル/ディレクトリを除外するための glob パターンマッチャ。
/// パターン形式は `.gitignore` 風 (basename glob / path prefix glob, `*` と `?` のみ対応)。
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
                if Self.globMatchPathPrefix(pattern: pattern, path: relativePath) { return true }
            } else {
                if Self.globMatch(pattern: pattern, target: basename) { return true }
            }
        }
        return false
    }

    /// `*` (任意文字列) と `?` (任意 1 文字) のみ対応する glob 完全一致
    private static func globMatch(pattern: String, target: String) -> Bool {
        let p = Array(pattern), t = Array(target)
        return matchHelper(p: p, pi: 0, t: t, ti: 0)
    }

    /// 再帰で glob パターンマッチを評価する補助関数
    private static func matchHelper(p: [Character], pi: Int, t: [Character], ti: Int) -> Bool {
        if pi >= p.count { return ti >= t.count }
        if p[pi] == "*" {
            for k in ti...t.count {
                if matchHelper(p: p, pi: pi + 1, t: t, ti: k) { return true }
            }
            return false
        }
        if ti >= t.count { return false }
        if p[pi] == "?" || p[pi] == t[ti] {
            return matchHelper(p: p, pi: pi + 1, t: t, ti: ti + 1)
        }
        return false
    }

    /// path prefix glob: pattern を `/` 区切りでセグメント分割し、path 先頭からセグメントごとに glob match。
    /// pattern のセグメント数だけ path の先頭が一致すれば、それより深い path もマッチ扱いとなる。
    private static func globMatchPathPrefix(pattern: String, path: String) -> Bool {
        let pSegs = pattern.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let tSegs = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if pSegs.count > tSegs.count { return false }
        for i in 0..<pSegs.count {
            if !globMatch(pattern: pSegs[i], target: tSegs[i]) { return false }
        }
        return true
    }
}
