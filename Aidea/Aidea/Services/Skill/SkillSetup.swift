//
//  SkillSetup.swift
//  Aidea
//

import Foundation
import CryptoKit

/// aidea.* の Claude Code 資産 (skill / command) を、アプリ Bundle から
/// user / project スコープの `~/.claude/(skills|commands)` へ配置するユーティリティ。
///
/// Bundle 内 `ClaudeAssets/` はフォルダ参照で同梱され、配置先と同じ
/// ディレクトリ構造をそのまま保持する。配置は「対応カテゴリへのミラーコピー」:
///
///   ClaudeAssets/user/skills/*      → ~/.claude/skills/*
///   ClaudeAssets/user/commands/*    → ~/.claude/commands/*
///   ClaudeAssets/project/skills/*   → <projectRoot>/.claude/skills/*
///   ClaudeAssets/project/commands/* → <projectRoot>/.claude/commands/*
///
/// 各リポジトリ固有の情報 (例: docs-healthcheck の specifics.md / round-table の cast.md) は
/// バンドルに含めず、そのリポジトリの project skill ディレクトリ側に直接置く (本機構は触らない)。
///
/// 各配置先ルートの管理マニフェスト `<root>/.aidea-managed.json` に配布済み hash を記録し、
/// ユーザ未編集のものだけ新版へ更新、編集済みは保護する (BackchannelSetup と同じ思想)。
/// 仕様: docs/specs/skills/skill-bootstrap.md / 決定: docs/decisions/0032-bundle-skills-to-user-scope.md
enum SkillSetup {

    private static let assetsDir = "ClaudeAssets"
    private static let manifestName = ".aidea-managed.json"

    /// Bundle 同梱の aidea.* 資産を 4 カテゴリへミラーコピーする。冪等。
    static func setup(projectRoot: URL) {
        guard let assetsRoot = Bundle.main.resourceURL?.appending(path: assetsDir) else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser

        // project スコープの配置先は開いたリポジトリが用意したものなので、
        // projectRoot より下にシンボリックリンクがあれば書き込まない (外部への書き込み防止)。
        // user スコープはユーザ自身の環境なのでリンク (dotfiles 管理等) を尊重する。
        let categories: [(sub: String, dest: URL, containRoot: URL?)] = [
            ("user/skills",      home.appending(path: ".claude/skills"),          nil),
            ("user/commands",    home.appending(path: ".claude/commands"),        nil),
            ("project/skills",   projectRoot.appending(path: ".claude/skills"),   projectRoot),
            ("project/commands", projectRoot.appending(path: ".claude/commands"), projectRoot),
        ]
        for category in categories {
            deploy(
                from: assetsRoot.appending(path: category.sub), to: category.dest,
                containRoot: category.containRoot
            )
        }
    }

    /// `src` 配下の全ファイルを `destRoot` に同じ相対パスでコピーする (ユーザ編集は保護)。
    /// `containRoot` 指定時は、その配下にリンクを含む経路への読み書きをすべて拒否する。
    private static func deploy(from src: URL, to destRoot: URL, containRoot: URL?) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: src.path),
              let enumerator = fm.enumerator(at: src, includingPropertiesForKeys: [.isDirectoryKey]) else { return }

        let isAllowed: (URL) -> Bool = { url in
            guard let containRoot else { return true }
            guard ContainedPath.isSafe(url, under: containRoot) else {
                NSLog("[Aidea] SkillSetup: refuse path outside project or via symlink \(url.path)")
                return false
            }
            return true
        }
        guard isAllowed(manifestURL(root: destRoot)) else { return }

        var manifest = loadManifest(root: destRoot)
        var changed = false

        for case let fileURL as URL in enumerator {
            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir { continue }
            if fileURL.lastPathComponent.hasPrefix(".") { continue } // .gitkeep 等は除外

            let rel = relativePath(of: fileURL, under: src)
            guard let body = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            guard isAllowed(destRoot.appending(path: rel)) else { continue }
            if placeFile(body: body, destRoot: destRoot, rel: rel, manifest: &manifest) {
                changed = true
            }
        }
        if changed { saveManifest(manifest, root: destRoot) }
    }

    /// 1 ファイルを配置する。配置/更新したら true。
    private static func placeFile(
        body: String, destRoot: URL, rel: String, manifest: inout [String: String]
    ) -> Bool {
        let dest = destRoot.appending(path: rel)
        let shippedHash = sha256(body)
        let fm = FileManager.default

        if fm.fileExists(atPath: dest.path) {
            // 読めないファイル (非 UTF-8 等) を空文字扱いにすると空ハッシュと一致して
            // 上書きされうるため、由来不明として保護する
            guard let current = try? String(contentsOf: dest, encoding: .utf8) else {
                NSLog("[Aidea] SkillSetup: keep unreadable asset \(rel)")
                return false
            }
            let currentHash = sha256(current)
            if manifest[rel] == currentHash {
                // ユーザ未編集 → Bundle が新しければ更新
                guard currentHash != shippedHash else { return false }
                write(body, to: dest)
                manifest[rel] = shippedHash
                return true
            } else {
                // ユーザ編集済み or マニフェスト未記載 (由来不明) → 保護
                NSLog("[Aidea] SkillSetup: keep user-modified asset \(rel)")
                return false
            }
        } else {
            write(body, to: dest)
            manifest[rel] = shippedHash
            return true
        }
    }

    /// `base` から見た `url` の相対パス (例: "aidea.docs-healthcheck/SKILL.md")
    private static func relativePath(of url: URL, under base: URL) -> String {
        let basePath = base.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(basePath) else { return url.lastPathComponent }
        return String(filePath.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func write(_ body: String, to dest: URL) {
        try? FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? Data(body.utf8).write(to: dest)
    }

    // MARK: - マニフェスト (<root>/.aidea-managed.json: { "version":1, "assets": { rel: hash } })

    private static func manifestURL(root: URL) -> URL { root.appending(path: manifestName) }

    private static func loadManifest(root: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: manifestURL(root: root)),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = obj["assets"] as? [String: String] else { return [:] }
        return assets
    }

    private static func saveManifest(_ assets: [String: String], root: URL) {
        let obj: [String: Any] = ["version": 1, "assets": assets]
        guard let data = try? JSONSerialization.data(
            withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? data.write(to: manifestURL(root: root))
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
