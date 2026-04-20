//
//  FileTreeLoader.swift
//  Aidea
//

import Foundation

/// ディレクトリの直下のみを走査して FileTreeNode 配列を返すローダ (遅延読み込み用)。
enum FileTreeLoader {

    /// 指定ディレクトリの直下を読み込む。エラー時は空配列。
    /// 除外ルールは適用しない (呼び出し側の `FileTreeViewController` が `ExcludeMatcher` で除外する)。
    static func load(directory url: URL, parent: FileTreeNode? = nil) -> [FileTreeNode] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }
        let nodes = entries.compactMap { entry -> FileTreeNode? in
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return FileTreeNode(url: entry, isDirectory: isDir, parent: parent)
        }
        // ディレクトリ優先、その後名前順
        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
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
