//
//  ContainedPath.swift
//  Aidea
//

import Foundation

/// 書き込み・削除先が信頼できるルート配下に収まっているかを検査するユーティリティ。
///
/// 開いたリポジトリは `.claude/skills` や `.aidea/ja` などをシンボリックリンクにして
/// 置けるため、ルートより下の経路にリンクがあるとプロジェクト外へ書き込んでしまう。
/// ルート自体 (ユーザが選んだ projectRoot) のリンクは許し、それより下の要素だけを
/// lstat で 1 つずつ確かめる。
enum ContainedPath {

    /// `target` が `root` の真下にあり、`root` より下の経路にシンボリックリンクが無いか判定する。
    /// まだ存在しない要素は作成予定とみなし、そこで検査を打ち切る (以降も存在しないため)。
    static func isSafe(_ target: URL, under root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let targetPath = target.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard targetPath.hasPrefix(prefix) else { return false }

        let components = targetPath.dropFirst(prefix.count)
            .split(separator: "/")
            .map(String.init)
        guard !components.isEmpty, !components.contains("..") else { return false }

        let fm = FileManager.default
        var current = URL(fileURLWithPath: rootPath, isDirectory: true)
        var deepestExisting = current
        for component in components {
            current = current.appendingPathComponent(component)
            // attributesOfItem は末尾のリンクをたどらない (lstat 相当)
            guard let attrs = try? fm.attributesOfItem(atPath: current.path) else { break }
            if attrs[.type] as? FileAttributeType == .typeSymbolicLink { return false }
            deepestExisting = current
        }

        // 念のため実在する最深の要素を実体パスに解決し、ルートの実体内に収まることも確かめる。
        // resolvingSymlinksInPath は実在有無で /private の扱いが変わるため realpath(3) を使う
        guard deepestExisting.path != rootPath else { return true }
        guard let realRoot = realPath(rootPath), let realTarget = realPath(deepestExisting.path) else {
            return false
        }
        let realPrefix = realRoot.hasSuffix("/") ? realRoot : realRoot + "/"
        return realTarget.hasPrefix(realPrefix)
    }

    /// realpath(3) でシンボリックリンクを全て解決した実体パスを返す (存在しなければ nil)
    private static func realPath(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
