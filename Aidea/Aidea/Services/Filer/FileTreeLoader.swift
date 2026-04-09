//
//  FileTreeLoader.swift
//  Aidea
//

import Foundation

/// ディレクトリの直下のみを走査して FileTreeNode 配列を返すローダ (遅延読み込み用)。
enum FileTreeLoader {

    /// 指定ディレクトリの直下を読み込む。エラー時は空配列。
    static func load(directory url: URL, parent: FileTreeNode? = nil) -> [FileTreeNode] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return []
        }
        // ノイズが大きいディレクトリ (.git など) のみ除外。その他の隠しファイルは表示する
        let excluded: Set<String> = [".git", "node_modules", "DerivedData", ".build", ".DS_Store"]
        let nodes = entries.compactMap { entry -> FileTreeNode? in
            if excluded.contains(entry.lastPathComponent) { return nil }
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
