//
//  GitFileTreeNode.swift
//  Aidea
//

import Foundation

/// Git 変更ファイル一覧をディレクトリツリーで表示するためのノード。
/// Filer の FileTreeNode に似ているが、変更ステータスを持つ。
final class GitFileTreeNode: Identifiable, Hashable {
    let id: String
    let name: String
    let isDirectory: Bool
    let status: GitChangedFile.Status?
    let isStaged: Bool
    let relativePath: String
    var children: [GitFileTreeNode]?

    init(name: String, isDirectory: Bool, status: GitChangedFile.Status?, isStaged: Bool = false, relativePath: String) {
        self.id = relativePath + (isStaged ? ":staged" : "")
        self.name = name
        self.isDirectory = isDirectory
        self.status = status
        self.isStaged = isStaged
        self.relativePath = relativePath
    }

    static func == (lhs: GitFileTreeNode, rhs: GitFileTreeNode) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// GitChangedFile のフラットリストをディレクトリツリーに変換する
    static func buildTree(from files: [GitChangedFile]) -> [GitFileTreeNode] {
        buildTreeRecursive(from: files, prefix: "")
    }

    private static func buildTreeRecursive(from files: [GitChangedFile], prefix: String) -> [GitFileTreeNode] {
        var dirs: [String: [GitChangedFile]] = [:]
        var leaves: [GitChangedFile] = []

        for file in files {
            let relative = prefix.isEmpty ? file.path : String(file.path.dropFirst(prefix.count + 1))
            let components = relative.split(separator: "/").map(String.init)
            if components.count == 1 {
                leaves.append(file)
            } else {
                let dirName = components[0]
                dirs[dirName, default: []].append(file)
            }
        }

        // ディレクトリ・ファイルを区別せず名前で混在ソート (Filer と同じ規約)
        // 共通ソート規約: docs/specs/aspects/sort-order.md
        let dirNodes: [GitFileTreeNode] = dirs.map { (dirName, children) in
            let dirPath = prefix.isEmpty ? dirName : prefix + "/" + dirName
            let node = GitFileTreeNode(name: dirName, isDirectory: true, status: nil, relativePath: dirPath)
            node.children = buildTreeRecursive(from: children, prefix: dirPath)
            return node
        }
        let fileNodes: [GitFileTreeNode] = leaves.map { file in
            let name = file.path.split(separator: "/").last.map(String.init) ?? file.path
            return GitFileTreeNode(name: name, isDirectory: false, status: file.status, isStaged: file.isStaged, relativePath: file.path)
        }
        return (dirNodes + fileNodes).sorted { $0.name.naturalAscending($1.name) }
    }
}
