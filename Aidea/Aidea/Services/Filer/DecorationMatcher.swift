//
//  DecorationMatcher.swift
//  Aidea
//

import Foundation

/// Filer のファイル/ディレクトリの相対パスから、適用される装飾 (アイコン + 色) を解決する。
///
/// `defaultDecorationRules` (Aidea 同梱の組み込み定数) → `userDecorationRules` (ユーザ追加分)
/// の順に連結した 1 本の配列を上から評価し、マッチした全ルールを **後勝ち** で合成する。
/// 後勝ち合成: 後ろのルールの `icon` / `color` が `nil` なら前のマッチルールの値を引き継ぐ。
///
/// glob パターンは `ExcludeMatcher` と同じ実装を使う (`*` / `?` / `<basename>` / `<path>/<...>`)。
/// 仕様: `docs/specs/tools/filer.md#デコレーション`
struct DecorationMatcher {
    /// Aidea 同梱の組み込みデフォルトルール (永続化対象外)
    let defaults: [DecorationRule]
    /// ユーザ追加ルール (`workspace.json` v6 に永続化される `userDecorationRules`)
    let userRules: [DecorationRule]

    /// 解決結果。
    struct Resolved {
        /// SF Symbol 名 / Asset 名。マッチなしなら nil。
        let icon: String?
        /// プリセットキー or hex `#RRGGBB`。マッチなしなら nil。
        let color: String?
    }

    /// 指定の相対パスに適用すべき装飾を返す。
    /// - Parameter relativePath: projectRoot からの相対パス (先頭スラッシュ無し)
    func resolve(relativePath: String) -> Resolved {
        var icon: String?
        var color: String?
        let rules = defaults + userRules
        let basename = (relativePath as NSString).lastPathComponent
        for rule in rules where !rule.pattern.isEmpty {
            let matched: Bool
            if rule.pattern.contains("/") {
                matched = Self.globMatchPathPrefix(pattern: rule.pattern, path: relativePath)
            } else {
                matched = Self.globMatch(pattern: rule.pattern, target: basename)
            }
            guard matched else { continue }
            if let i = rule.icon { icon = i }
            if let c = rule.color { color = c }
        }
        return Resolved(icon: icon, color: color)
    }

    // MARK: - Glob (ExcludeMatcher と同じロジック)

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
