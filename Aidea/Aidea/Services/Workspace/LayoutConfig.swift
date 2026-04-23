//
//  LayoutConfig.swift
//  Aidea
//

import Foundation
import Observation

/// 動的ペイン構成。`root` は LayoutNode ツリーで、leaf が Pane を保持する。
/// 初期値は持たず、起動時に `WorkspaceSnapshotManager.apply()` で必ず上書きされる。
/// デフォルトレイアウトの SSoT は Bundle 同梱 `Aidea/Resources/default-workspace.json`。
@Observable
final class LayoutConfig {
    /// レイアウトツリーのルート
    var root: LayoutNode

    /// 空 root で初期化する。実際の root は apply() で上書きされる前提。
    init() {
        // 仮の最小レイアウト (Filer 1 ペイン)。
        // 通常は AideaApp.init() で snapshot.apply() により即座に上書きされる
        self.root = Self.fallbackRoot()
    }

    init(root: LayoutNode) {
        self.root = root
    }

    /// 緊急フォールバック用の最小レイアウト (Filer 1 ペイン)。
    /// Bundle テンプレ読込にも失敗した場合のみ使われる
    static func fallbackRoot() -> LayoutNode {
        LayoutNode(value: .leaf(Pane(tabs: [SessionID(.filer)])))
    }

    /// 全 Pane の配列 (Tool インスタンス番号採番などで横断的に参照)
    var allPanes: [Pane] { root.collectPanes() }

    /// 全 leaf LayoutNode の配列
    var allLeafNodes: [LayoutNode] { root.collectLeafNodes() }

    /// 指定 tool の新しい Session インスタンス番号を採番する
    func nextSessionInstance(of tool: Tool) -> Int {
        let used = Set(allPanes.flatMap { $0.tabs }.filter { $0.tool == tool }.map { $0.instance })
        var instance = 0
        while used.contains(instance) { instance += 1 }
        return instance
    }

    /// 指定の leaf ノードを分割する。`target` を新しい split ノードで置き換え、
    /// 既存のペインと空の新ペイン (Terminal) を並べる。
    /// - Returns: 新しく作られたペイン (呼び出し側がフォーカスを当てられるように)
    @discardableResult
    func splitLeaf(_ target: LayoutNode, axis: LayoutNode.Axis) -> Pane? {
        guard case .leaf(let existingPane) = target.value else { return nil }
        // 新しい空ペイン: とりあえず Terminal を 1 つ置く (インスタンスは採番)
        let newInstance = nextSessionInstance(of: .terminal)
        let newPane = Pane(tabs: [SessionID(.terminal, instance: newInstance)])
        let keptLeaf = LayoutNode(value: .leaf(existingPane))
        let newLeaf = LayoutNode(value: .leaf(newPane))
        // target のノード値を split に差し替え (id は維持)
        target.value = .split(axis: axis, children: [keptLeaf, newLeaf])
        return newPane
    }

    /// 指定の leaf ノードを削除する。親 split の子が 1 つ残った場合は
    /// その親 split を折りたたんで単一 leaf に置き換える。
    /// ルート自身が leaf の場合は何もしない (最後のペインは残す)。
    func removeLeaf(_ target: LayoutNode) {
        if root.id == target.id {
            return
        }
        _ = removeFromTree(target: target, in: root)
    }

    /// 再帰的に target を親 split から取り除く。取り除いた場合 true。
    @discardableResult
    private func removeFromTree(target: LayoutNode, in node: LayoutNode) -> Bool {
        guard case .split(let axis, var children) = node.value else {
            return false
        }
        if let index = children.firstIndex(where: { $0.id == target.id }) {
            children.remove(at: index)
            if children.count == 1 {
                // 親 split の子が 1 つだけ → 親を子の値で置き換える
                node.value = children[0].value
            } else {
                node.value = .split(axis: axis, children: children)
            }
            return true
        }
        for child in children {
            if removeFromTree(target: target, in: child) {
                return true
            }
        }
        return false
    }
}
