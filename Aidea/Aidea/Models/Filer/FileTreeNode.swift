//
//  FileTreeNode.swift
//  Aidea
//

import Foundation

/// ファイラのツリーを構成する 1 ノード。NSOutlineView の item として参照同一性を使うため class。
/// `children` が `nil` の状態は「未走査」を意味する (展開時に初期化される)。
final class FileTreeNode: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    /// nil = 未走査 / [] = 走査済みで子なし
    var children: [FileTreeNode]?
    /// 親ノードへの弱参照 (FSEvents 通知時の探索に使う)
    weak var parent: FileTreeNode?

    init(url: URL, isDirectory: Bool, parent: FileTreeNode? = nil) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.parent = parent
    }

    static func == (lhs: FileTreeNode, rhs: FileTreeNode) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
