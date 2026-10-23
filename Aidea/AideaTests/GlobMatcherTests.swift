//
//  GlobMatcherTests.swift
//  AideaTests
//

import XCTest
@testable import Aidea

/// Filer の除外ルール / デコレーションが共有する `GlobMatcher` の照合結果と計算量を検証する。
/// 仕様: docs/specs/tools/filer.md#除外ルール / issue #300 (F20/F21)
final class GlobMatcherTests: XCTestCase {

    // MARK: - helpers

    /// 置き換え前の再帰実装 (参照実装)。新実装と結果が一致することの確認にだけ使う
    private func referenceMatch(_ p: [Character], _ pi: Int, _ t: [Character], _ ti: Int) -> Bool {
        if pi >= p.count { return ti >= t.count }
        if p[pi] == "*" {
            for k in ti...t.count where referenceMatch(p, pi + 1, t, k) { return true }
            return false
        }
        if ti >= t.count { return false }
        if p[pi] == "?" || p[pi] == t[ti] { return referenceMatch(p, pi + 1, t, ti + 1) }
        return false
    }

    // MARK: - basename glob

    func testLiteralAndWildcards() {
        XCTAssertTrue(GlobMatcher.matches(pattern: ".git", target: ".git"))
        XCTAssertFalse(GlobMatcher.matches(pattern: ".git", target: ".gitignore"))
        XCTAssertTrue(GlobMatcher.matches(pattern: "*.swift", target: "Main.swift"))
        XCTAssertFalse(GlobMatcher.matches(pattern: "*.swift", target: "Main.swift.bak"))
        XCTAssertTrue(GlobMatcher.matches(pattern: "a?c", target: "abc"))
        XCTAssertFalse(GlobMatcher.matches(pattern: "a?c", target: "ac"))
        XCTAssertTrue(GlobMatcher.matches(pattern: "*", target: ""))
        XCTAssertTrue(GlobMatcher.matches(pattern: "", target: ""))
        XCTAssertFalse(GlobMatcher.matches(pattern: "", target: "a"))
        XCTAssertTrue(GlobMatcher.matches(pattern: "a**b", target: "ab"))
        XCTAssertTrue(GlobMatcher.matches(pattern: "*a*b*", target: "xxaxxbxx"))
        XCTAssertFalse(GlobMatcher.matches(pattern: "*a*b", target: "xxbxxa"))
        // `[` などは特殊文字ではなくリテラル
        XCTAssertTrue(GlobMatcher.matches(pattern: "[ab]", target: "[ab]"))
        XCTAssertFalse(GlobMatcher.matches(pattern: "[ab]", target: "a"))
    }

    /// 小さなアルファベット上の全組み合わせで、旧再帰実装と同じ結果になること
    func testEquivalentToReferenceImplementation() {
        let patternAlphabet: [Character] = ["a", "b", "*", "?"]
        let targetAlphabet: [Character] = ["a", "b"]
        func all(_ alphabet: [Character], upTo n: Int) -> [[Character]] {
            var result: [[Character]] = [[]]
            var layer: [[Character]] = [[]]
            for _ in 0..<n {
                layer = layer.flatMap { s in alphabet.map { s + [$0] } }
                result += layer
            }
            return result
        }
        let patterns = all(patternAlphabet, upTo: 5)
        let targets = all(targetAlphabet, upTo: 6)
        for p in patterns {
            for t in targets {
                XCTAssertEqual(
                    GlobMatcher.matches(pattern: String(p), target: String(t)),
                    referenceMatch(p, 0, t, 0),
                    "pattern=\(String(p)) target=\(String(t))"
                )
            }
        }
    }

    /// 旧実装で指数的バックトラックを起こしたパターンでも即座に終わること
    func testPathologicalPatternFinishesFast() {
        let pattern = String(repeating: "*a", count: 30) + "*b"
        let target = String(repeating: "a", count: 5000)
        let start = Date()
        XCTAssertFalse(GlobMatcher.matches(pattern: pattern, target: target))
        XCTAssertTrue(GlobMatcher.matches(pattern: pattern, target: target + "b"))
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
    }

    // MARK: - path prefix glob

    func testPathPrefix() {
        XCTAssertTrue(GlobMatcher.matchesPathPrefix(pattern: "build/", path: "build"))
        XCTAssertTrue(GlobMatcher.matchesPathPrefix(pattern: "build/", path: "build/out/a.o"))
        XCTAssertTrue(GlobMatcher.matchesPathPrefix(pattern: "docs/*.md", path: "docs/README.md"))
        XCTAssertTrue(GlobMatcher.matchesPathPrefix(pattern: "docs/*.md", path: "docs/a.md/inner"))
        XCTAssertFalse(GlobMatcher.matchesPathPrefix(pattern: "docs/*.md", path: "docs"))
        XCTAssertFalse(GlobMatcher.matchesPathPrefix(pattern: "docs/*.md", path: "src/README.md"))
        // `*` はセグメント境界 `/` をまたがない
        XCTAssertFalse(GlobMatcher.matchesPathPrefix(pattern: "a*/c", path: "ab/x/c"))
    }

    // MARK: - 利用側

    func testExcludeAndDecorationMatchersUseSharedSemantics() {
        let exclude = ExcludeMatcher(patterns: ["*.log", "build/"])
        XCTAssertTrue(exclude.matches(relativePath: "src/debug.log"))
        XCTAssertTrue(exclude.matches(relativePath: "build/x"))
        XCTAssertFalse(exclude.matches(relativePath: "src/main.swift"))

        let decoration = DecorationMatcher(
            defaults: [DecorationRule(pattern: "*.md", icon: "doc", color: nil)],
            userRules: [DecorationRule(pattern: "docs/", icon: nil, color: "blue")]
        )
        let resolved = decoration.resolve(relativePath: "docs/a.md")
        XCTAssertEqual(resolved.icon, "doc")
        XCTAssertEqual(resolved.color, "blue")
    }
}
