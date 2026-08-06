//
//  TerminalPathResolverTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// ターミナル出力中のファイルパス検出・解決を検証する。
/// 手動で確認していた代表ケースを自動化したもの。
/// 仕様: docs/specs/tools/terminal.md#ファイルパスのクリック起動-issue-71
struct TerminalPathResolverTests {

    /// 一時ディレクトリに実ファイルを用意する (実在確認を通すため)
    private func withProject(
        files: [String],
        _ body: (URL) throws -> Void
    ) throws {
        // NSTemporaryDirectory() は /var/... を返すが、ディレクトリ列挙で得られる URL は
        // /private/var/... の正規形になる (macOS の firmlink)。resolvingSymlinksInPath は
        // /var を解決しないため、canonicalPath で正規形を取って表現を揃える。
        // 揃えないと projectRoot 起点の相対化 (displayPath) の比較が実環境と食い違う。
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aidea-pathresolver-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let canonical = try #require(base.resourceValues(forKeys: [.canonicalPathKey]).canonicalPath)
        let root = URL(fileURLWithPath: canonical)

        for relative in files {
            let url = root.appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try Data().write(to: url)
        }
        try body(root)
    }

    /// 行内で対象文字列の中央にあたる列を返す (クリック位置の代用)
    private func column(of needle: String, in line: String) throws -> Int {
        let range = try #require(line.range(of: needle))
        let start = line.distance(from: line.startIndex, to: range.lowerBound)
        return start + needle.count / 2
    }

    @Test("projectRoot 起点の相対パスを解決する")
    func resolvesRelativePath() throws {
        try withProject(files: ["Sources/Foo.swift"]) { root in
            let line = "error in Sources/Foo.swift here"
            let col = try column(of: "Sources/Foo.swift", in: line)
            let match = try #require(TerminalPathResolver.match(in: line, at: col, projectRoot: root))

            #expect(match.path == "Sources/Foo.swift")
            #expect(match.displayPath == "Sources/Foo.swift")
            #expect(match.line == nil)
        }
    }

    @Test("絶対パスは projectRoot なしでも解決する")
    func resolvesAbsolutePath() throws {
        try withProject(files: ["main.go"]) { root in
            let absolute = root.appendingPathComponent("main.go").path
            let line = "see \(absolute) for details"
            let col = try column(of: absolute, in: line)
            let match = try #require(TerminalPathResolver.match(in: line, at: col, projectRoot: nil))

            #expect(match.path == absolute)
            #expect(match.displayPath == absolute)
        }
    }

    @Test("末尾の :行数 を行番号として切り出し、パス自体には含めない")
    func parsesLineNumberSuffix() throws {
        try withProject(files: ["docs/spec.md"]) { root in
            let line = "docs/spec.md:42: warning"
            let col = try column(of: "docs/spec.md", in: line)
            let match = try #require(TerminalPathResolver.match(in: line, at: col, projectRoot: root))

            #expect(match.path == "docs/spec.md")
            #expect(match.line == 42)
        }
    }

    @Test("./ 始まりの相対パスも解決する")
    func resolvesDotSlashPath() throws {
        try withProject(files: ["build/output.json"]) { root in
            let line = "wrote ./build/output.json"
            let col = try column(of: "build/output.json", in: line)
            let match = try #require(TerminalPathResolver.match(in: line, at: col, projectRoot: root))

            #expect(match.absoluteURL.lastPathComponent == "output.json")
        }
    }

    @Test("実在しないパスは検出しても解決しない")
    func rejectsNonExistentPath() throws {
        try withProject(files: ["real.swift"]) { root in
            let line = "missing/ghost.swift was not found"
            let col = try column(of: "missing/ghost.swift", in: line)

            #expect(TerminalPathResolver.match(in: line, at: col, projectRoot: root) == nil)
        }
    }

    @Test("拡張子のない語・IP アドレスはパスとして検出しない")
    func ignoresNonPathTokens() throws {
        try withProject(files: ["real.swift"]) { root in
            for line in ["listening on 192.168.1.1 now", "run Makefile please"] {
                let matches = TerminalPathResolver.detectPaths(in: line, projectRoot: root)
                #expect(matches.isEmpty, "「\(line)」からパスを検出してはいけない")
            }
        }
    }

    @Test("クリック位置がパス範囲外なら解決しない")
    func requiresColumnInsideRange() throws {
        try withProject(files: ["Sources/Foo.swift"]) { root in
            let line = "Sources/Foo.swift trailing text"
            let outside = line.count - 1

            #expect(TerminalPathResolver.match(in: line, at: outside, projectRoot: root) == nil)
        }
    }

    @Test("プロジェクト内検索フォールバック: 1 件だけ一致すればそれを開く")
    func fallbackFindsSingleMatch() throws {
        try withProject(files: ["deep/nested/unique.swift"]) { root in
            // projectRoot 直下には無いファイル名だけを書いた行
            let line = "at unique.swift:10"
            let col = try column(of: "unique.swift", in: line)

            switch TerminalPathResolver.matchWithFallback(in: line, at: col, projectRoot: root) {
            case .single(let match):
                #expect(match.displayPath == "deep/nested/unique.swift")
                #expect(match.line == 10)
            case .none, .multiple:
                Issue.record("単一ヒットになるはず")
            }
        }
    }

    @Test("プロジェクト内検索フォールバック: 複数一致は候補を全部返す")
    func fallbackReturnsMultipleCandidates() throws {
        try withProject(files: ["a/dup.swift", "b/dup.swift"]) { root in
            let line = "see dup.swift"
            let col = try column(of: "dup.swift", in: line)

            switch TerminalPathResolver.matchWithFallback(in: line, at: col, projectRoot: root) {
            case .multiple(let matches):
                #expect(matches.count == 2)
            case .none, .single:
                Issue.record("複数候補になるはず")
            }
        }
    }

    @Test("絶対パスはプロジェクト内検索フォールバックに進まない")
    func fallbackSkipsAbsolutePaths() throws {
        try withProject(files: ["a/dup.swift"]) { root in
            let line = "/nonexistent/dup.swift missing"
            let col = try column(of: "/nonexistent/dup.swift", in: line)

            switch TerminalPathResolver.matchWithFallback(in: line, at: col, projectRoot: root) {
            case .none:
                break // 期待どおり
            case .single, .multiple:
                Issue.record("絶対パスは検索フォールバックの対象外")
            }
        }
    }
}
