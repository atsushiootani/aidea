//
//  FileTreeNode.swift
//  Aidea
//

import Foundation

/// ファイラのツリーを構成する 1 ノード。NSOutlineView の item として参照同一性を使うため class。
/// `children` が `nil` の状態は「未走査」を意味する (展開時に初期化される)。
/// `isDirectory` はシンボリックリンクの場合「解決先がディレクトリか」を表す (issue #119)。
final class FileTreeNode: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    /// シンボリックリンク自身であるか (issue #119)。循環リンク検知に使う。
    let isSymbolicLink: Bool
    /// nil = 未走査 / [] = 走査済みで子なし
    var children: [FileTreeNode]?
    /// 親ノードへの弱参照 (FSEvents 通知時の探索に使う)
    weak var parent: FileTreeNode?

    init(url: URL, isDirectory: Bool, parent: FileTreeNode? = nil, isSymbolicLink: Bool = false) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
        self.parent = parent
    }

    static func == (lhs: FileTreeNode, rhs: FileTreeNode) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
