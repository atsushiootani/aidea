//
//  GlobMatcher.swift
//  Aidea
//

import Foundation

/// `ExcludeMatcher` と `DecorationMatcher` が共有する glob 照合ロジック。
/// 対応するメタ文字は `*` (任意文字列) と `?` (任意 1 文字) のみ。
/// パターン・対象とも workspace.json やリポジトリ由来で信頼できないため、
/// 入力長に対して線形時間 (最悪 O(パターン長 × 対象長)) で終わる 2 ポインタ方式で評価する。
enum GlobMatcher {
    /// `*` と `?` のみ対応する glob 完全一致
    static func matches(pattern: String, target: String) -> Bool {
        let p = Array(pattern), t = Array(target)
        var pi = 0, ti = 0
        // 直近の `*` の位置と、その `*` に吸わせ始めた対象側の位置 (バックトラック先)
        var starPi = -1, starTi = 0
        while ti < t.count {
            if pi < p.count, p[pi] == "*" {
                starPi = pi
                starTi = ti
                pi += 1
            } else if pi < p.count, p[pi] == "?" || p[pi] == t[ti] {
                pi += 1
                ti += 1
            } else if starPi >= 0 {
                // 直近の `*` に 1 文字多く吸わせてやり直す。それより前の `*` まで戻る必要はない
                starTi += 1
                pi = starPi + 1
                ti = starTi
            } else {
                return false
            }
        }
        // 対象を使い切ったら、残りのパターンが `*` だけなら一致
        while pi < p.count, p[pi] == "*" { pi += 1 }
        return pi == p.count
    }

    /// path prefix glob: pattern を `/` 区切りでセグメント分割し、path 先頭からセグメントごとに glob match。
    /// pattern のセグメント数だけ path の先頭が一致すれば、それより深い path もマッチ扱いとなる。
    static func matchesPathPrefix(pattern: String, path: String) -> Bool {
        let pSegs = pattern.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let tSegs = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if pSegs.count > tSegs.count { return false }
        for i in 0..<pSegs.count {
            if !matches(pattern: pSegs[i], target: tSegs[i]) { return false }
        }
        return true
    }
}
