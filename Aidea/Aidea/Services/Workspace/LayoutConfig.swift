//
//  LayoutConfig.swift
//  Aidea
//

import Foundation
import Observation

/// 1 つの物理ペインが保持する Tab のリストとアクティブなタブ位置。
/// 各 Tab は 1 つの Session を参照する。
@Observable
final class Pane: Identifiable {
    let id = UUID()
    var tabs: [SessionID]
    var activeIndex: Int

    init(tabs: [SessionID], activeIndex: Int = 0) {
        self.tabs = tabs
        self.activeIndex = activeIndex
    }

    /// 現在アクティブな SessionID。tabs が空なら nil。
    var activeSessionID: SessionID? {
        guard activeIndex >= 0, activeIndex < tabs.count else { return nil }
        return tabs[activeIndex]
    }
}

/// 動的ペイン構成。`root` は LayoutNode ツリーで、leaf が Pane を保持する。
@Observable
final class LayoutConfig {
    /// レイアウトツリーのルート
    var root: LayoutNode

    init() {
        self.root = Self.defaultRoot()
    }

    init(root: LayoutNode) {
        self.root = root
    }

    /// 既定の 4 ペインレイアウトを構築する
    static func defaultRoot() -> LayoutNode {
        let topLeft = LayoutNode(value: .leaf(Pane(tabs: [SessionID(.filer)])))
        let bottomLeft = LayoutNode(value: .leaf(Pane(tabs: [SessionID(.kit)])))
        let left = LayoutNode(value: .split(axis: .vertical, children: [topLeft, bottomLeft]))
        let center = LayoutNode(value: .leaf(Pane(tabs: [SessionID(.terminal)])))
        let right = LayoutNode(value: .leaf(Pane(tabs: [SessionID(.web)])))
        return LayoutNode(value: .split(axis: .horizontal, children: [left, center, right]))
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
