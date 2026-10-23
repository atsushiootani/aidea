//
//  ContainedPathTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// 書き込み先の封じ込め判定 (ContainedPath / TranslationCache) を検証する。
/// リポジトリが置いたシンボリックリンク経由でプロジェクト外へ書き込まないことを確かめる (issue #297)。
struct ContainedPathTests {

    /// 一時ディレクトリに project / outside の 2 ディレクトリを用意する
    private func withSandbox(_ body: (_ project: URL, _ outside: URL) throws -> Void) throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aidea-contained-\(UUID().uuidString)")
        let project = base.appendingPathComponent("project")
        let outside = base.appendingPathComponent("outside")
        let fm = FileManager.default
        try fm.createDirectory(at: project, withIntermediateDirectories: true)
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        try body(project, outside)
    }

    @Test func 通常のファイルと未作成の経路は許可される() throws {
        try withSandbox { project, _ in
            let dir = project.appendingPathComponent(".claude/skills/aidea.x")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data().write(to: dir.appendingPathComponent("SKILL.md"))

            #expect(ContainedPath.isSafe(dir.appendingPathComponent("SKILL.md"), under: project))
            #expect(ContainedPath.isSafe(project.appendingPathComponent("new/dir/file.md"), under: project))
        }
    }

    @Test func ルート外とルート自身と兄弟プレフィックスは拒否される() throws {
        try withSandbox { project, outside in
            #expect(!ContainedPath.isSafe(outside.appendingPathComponent("a.md"), under: project))
            #expect(!ContainedPath.isSafe(project, under: project))
            let sibling = URL(fileURLWithPath: project.path + "evil/a.md")
            #expect(!ContainedPath.isSafe(sibling, under: project))
            let dotdot = URL(fileURLWithPath: project.path + "/sub/../../outside/a.md")
            #expect(!ContainedPath.isSafe(dotdot, under: project))
        }
    }

    @Test func 途中のディレクトリがリンクなら拒否される() throws {
        try withSandbox { project, outside in
            let fm = FileManager.default
            try fm.createDirectory(at: project.appendingPathComponent(".aidea"), withIntermediateDirectories: true)
            try fm.createSymbolicLink(at: project.appendingPathComponent(".aidea/ja"), withDestinationURL: outside)

            let target = project.appendingPathComponent(".aidea/ja/CLAUDE.md")
            #expect(!ContainedPath.isSafe(target, under: project))
        }
    }

    @Test func プロジェクト内を指すリンクでも拒否される() throws {
        try withSandbox { project, _ in
            let fm = FileManager.default
            try fm.createDirectory(at: project.appendingPathComponent("real"), withIntermediateDirectories: true)
            try fm.createSymbolicLink(
                at: project.appendingPathComponent("link"), withDestinationURL: project.appendingPathComponent("real")
            )
            #expect(!ContainedPath.isSafe(project.appendingPathComponent("link/a.md"), under: project))
        }
    }

    @Test func 末尾のファイルがリンクなら宛先の有無によらず拒否される() throws {
        try withSandbox { project, outside in
            let fm = FileManager.default
            let dir = project.appendingPathComponent(".claude/skills/aidea.x")
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            // 宛先が無いダングリングリンク (fileExists は false を返す)
            try fm.createSymbolicLink(
                at: dir.appendingPathComponent("SKILL.md"), withDestinationURL: outside.appendingPathComponent("none")
            )
            #expect(!ContainedPath.isSafe(dir.appendingPathComponent("SKILL.md"), under: project))
        }
    }

    @Test func ルート自身がリンクなのは許可される() throws {
        try withSandbox { project, outside in
            let linkedRoot = outside.appendingPathComponent("root-link")
            try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: project)
            #expect(ContainedPath.isSafe(linkedRoot.appendingPathComponent("a/b.md"), under: linkedRoot))
        }
    }

    @Test func 翻訳キャッシュはjaディレクトリのリンクを拒否する() throws {
        try withSandbox { project, outside in
            let original = project.appendingPathComponent("docs/README.md")
            let cached = try #require(TranslationCache.cachedURL(for: original, projectRoot: project))
            #expect(TranslationCache.isSafeToWrite(cached, projectRoot: project))

            let fm = FileManager.default
            try fm.createDirectory(at: project.appendingPathComponent(".aidea"), withIntermediateDirectories: true)
            try fm.createSymbolicLink(at: project.appendingPathComponent(".aidea/ja"), withDestinationURL: outside)
            #expect(!TranslationCache.isSafeToWrite(cached, projectRoot: project))
        }
    }

    @Test func cachedURLは兄弟プレフィックスのディレクトリをルート外とみなす() {
        let root = URL(fileURLWithPath: "/tmp/proj")
        #expect(TranslationCache.cachedURL(for: URL(fileURLWithPath: "/tmp/projevil/a.md"), projectRoot: root) == nil)
        #expect(TranslationCache.cachedURL(for: root, projectRoot: root) == nil)
        let inside = TranslationCache.cachedURL(for: URL(fileURLWithPath: "/tmp/proj/docs/a.md"), projectRoot: root)
        #expect(inside?.path == "/tmp/proj/.aidea/ja/docs/a.md")
    }
}
