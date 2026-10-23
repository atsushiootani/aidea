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
/// glob パターンは `ExcludeMatcher` と共通の `GlobMatcher` で照合する (`*` / `?` / `<basename>` / `<path>/<...>`)。
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
                matched = GlobMatcher.matchesPathPrefix(pattern: rule.pattern, path: relativePath)
            } else {
                matched = GlobMatcher.matches(pattern: rule.pattern, target: basename)
            }
            guard matched else { continue }
            if let i = rule.icon { icon = i }
            if let c = rule.color { color = c }
        }
        return Resolved(icon: icon, color: color)
    }
}
