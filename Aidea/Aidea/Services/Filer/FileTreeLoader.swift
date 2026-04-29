//
//  FileTreeLoader.swift
//  Aidea
//

import Foundation

/// ディレクトリの直下のみを走査して FileTreeNode 配列を返すローダ (遅延読み込み用)。
enum FileTreeLoader {

    /// 指定ディレクトリの直下を読み込む。エラー時は空配列。
    /// 除外ルールは適用しない (呼び出し側の `FileTreeViewController` が `ExcludeMatcher` で除外する)。
    /// シンボリックリンクは解決先の種別で `isDirectory` を判定し、リンクであることを `isSymbolicLink` に保持する (issue #119)。
    /// `url` 自体がディレクトリへのシンボリックリンクの場合、`contentsOfDirectory` が ENOTDIR を返すので
    /// 解決先のパスで読み込み、子の URL はリンク経由のパスに付け替える (永続化キーをリンク経由で揃えるため)。
    static func load(directory url: URL, parent: FileTreeNode? = nil) -> [FileTreeNode] {
        let fm = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        // url 自体が symlink ならその解決先で contentsOfDirectory を呼ぶ
        let scanURL: URL = {
            let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values?.isSymbolicLink == true {
                return url.resolvingSymlinksInPath()
            }
            return url
        }()
        guard let entries = try? fm.contentsOfDirectory(
            at: scanURL,
            includingPropertiesForKeys: resourceKeys,
            options: []
        ) else {
            return []
        }
        let nodes = entries.compactMap { entry -> FileTreeNode? in
            // 子の URL はリンク経由のパス (親が link なら link 配下) を維持する
            let childURL = url.appendingPathComponent(entry.lastPathComponent)
            let values = try? entry.resourceValues(forKeys: Set(resourceKeys))
            let isSymlink = values?.isSymbolicLink ?? false
            let isDir: Bool
            if isSymlink {
                // シンボリックリンクは解決先の種別で再評価する (issue #119)。
                // broken link の場合は resolved 側の isDirectoryKey が取得できず false 扱い。
                let resolved = entry.resolvingSymlinksInPath()
                let resolvedValues = try? resolved.resourceValues(forKeys: [.isDirectoryKey])
                isDir = resolvedValues?.isDirectory ?? false
            } else {
                isDir = values?.isDirectory ?? false
            }
            return FileTreeNode(url: childURL, isDirectory: isDir, parent: parent, isSymbolicLink: isSymlink)
        }
        // ファイル/ディレクトリを区別せず名前順 (Finder 互換の自然順、issue #122)
        return nodes.sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// FileTreeNode に対応する SF Symbols 名を返す
    static func iconName(for node: FileTreeNode) -> String {
        if node.isDirectory { return "folder" }
        // drawio は拡張子だけでは判定できない (.drawio.svg は ext = svg) ので
        // ファイル名末尾を見る
        let name = node.url.lastPathComponent.lowercased()
        if name.hasSuffix(".drawio") || name.hasSuffix(".drawio.svg") {
            // Assets.xcassets の "drawio" という名前のアセットを参照する
            // (FileTreeViewController のセル生成側で NSImage(named:) でフォールバックする)
            return "drawio"
        }
        switch node.url.pathExtension.lowercased() {
        case "swift":                return "swift"
        case "md", "markdown":       return "doc.text"
        case "json", "yaml", "yml":  return "doc.badge.gearshape"
        case "png", "jpg", "jpeg", "gif", "heic", "webp": return "photo"
        case "pdf":                  return "doc.richtext"
        case "zip", "tar", "gz":     return "doc.zipper"
        case "sh", "zsh", "bash":    return "terminal"
        default:                     return "doc"
        }
    }
}
