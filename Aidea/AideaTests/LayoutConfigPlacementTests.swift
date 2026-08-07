//
//  LayoutConfigPlacementTests.swift
//  AideaTests
//

import Testing
@testable import Aidea

/// 固定配置先 (右端ペイン / 中央ペイン) の算出をレイアウト木の形ごとに検証する。
/// 仕様: docs/specs/sessions/active-session.md#固定配置先とペインの並び順-issue-275
@MainActor
struct LayoutConfigPlacementTests {

    /// tabs にツール種別を 1 つ置いた leaf を作る (ペインの同一性判定用の目印になる)
    private func leaf(_ tool: Tool, _ instance: Int) -> (LayoutNode, Pane) {
        let pane = Pane(tabs: [SessionID(tool, instance: instance)])
        return (LayoutNode(value: .leaf(pane)), pane)
    }

    @Test("ペインが 1 つなら右端も中央もそのペイン")
    func singlePane() {
        let (node, pane) = leaf(.filer, 0)
        let layout = LayoutConfig(root: node)

        #expect(layout.rightmostPane === pane)
        #expect(layout.centerPane === pane)
    }

    @Test("左右分割では右端 = 右の子")
    func horizontalSplitPicksRightChild() {
        let (leftNode, left) = leaf(.filer, 0)
        let (rightNode, right) = leaf(.web, 0)
        let layout = LayoutConfig(root: LayoutNode(value: .split(axis: .horizontal, children: [leftNode, rightNode])))

        #expect(layout.rightmostPane === right)
        #expect(layout.rightmostPane !== left)
    }

    @Test("右端の領域が上下分割されている場合は上のペインを選ぶ")
    func rightmostPrefersTopWhenVerticallySplit() {
        let (leftNode, left) = leaf(.filer, 0)
        let (topNode, top) = leaf(.web, 0)
        let (bottomNode, bottom) = leaf(.preview, 0)
        let rightColumn = LayoutNode(value: .split(axis: .vertical, children: [topNode, bottomNode]))
        let layout = LayoutConfig(root: LayoutNode(value: .split(axis: .horizontal, children: [leftNode, rightColumn])))

        #expect(layout.rightmostPane === top)
        #expect(layout.rightmostPane !== bottom)
        #expect(layout.rightmostPane !== left)
    }

    @Test("上下分割だけのときは上のペインが右端扱い")
    func verticalOnlyPicksTop() {
        let (topNode, top) = leaf(.terminal, 0)
        let (bottomNode, _) = leaf(.claude, 0)
        let layout = LayoutConfig(root: LayoutNode(value: .split(axis: .vertical, children: [topNode, bottomNode])))

        #expect(layout.rightmostPane === top)
    }

    @Test("中央ペインは並び順の中央 (奇数個)")
    func centerPaneOddCount() {
        let (n0, p0) = leaf(.filer, 0)
        let (n1, p1) = leaf(.claude, 0)
        let (n2, p2) = leaf(.web, 0)
        let layout = LayoutConfig(root: LayoutNode(value: .split(axis: .horizontal, children: [n0, n1, n2])))

        #expect(layout.allPanes.count == 3)
        #expect(layout.centerPane === p1)
        #expect(layout.centerPane !== p0)
        #expect(layout.centerPane !== p2)
    }

    @Test("中央ペインは偶数個のとき左寄り (4 ペインなら 2 番目)")
    func centerPaneEvenCountPrefersLeft() {
        let (n0, p0) = leaf(.filer, 0)
        let (n1, p1) = leaf(.terminal, 0)
        let (n2, p2) = leaf(.claude, 0)
        let (n3, p3) = leaf(.web, 0)
        let layout = LayoutConfig(root: LayoutNode(value: .split(axis: .horizontal, children: [n0, n1, n2, n3])))

        #expect(layout.allPanes.count == 4)
        #expect(layout.centerPane === p1)
        #expect(layout.centerPane !== p0)
        #expect(layout.centerPane !== p2)
        #expect(layout.centerPane !== p3)
    }

    @Test("右端と中央は入れ子レイアウトでも並び順に従う")
    func nestedLayoutOrdering() {
        // [ [filer | terminal] | [claude / web] ] → 並び順: filer, terminal, claude, web
        let (n0, p0) = leaf(.filer, 0)
        let (n1, p1) = leaf(.terminal, 0)
        let (n2, _) = leaf(.claude, 0)
        let (n3, _) = leaf(.web, 0)
        let leftGroup = LayoutNode(value: .split(axis: .horizontal, children: [n0, n1]))
        let rightGroup = LayoutNode(value: .split(axis: .vertical, children: [n2, n3]))
        let layout = LayoutConfig(root: LayoutNode(value: .split(axis: .horizontal, children: [leftGroup, rightGroup])))

        // 並び順の中央 (4 個 → 2 番目) は terminal
        #expect(layout.centerPane === p1)
        #expect(layout.centerPane !== p0)
        // 右端グループは上下分割なので上 (claude) が右端
        #expect(layout.rightmostPane === layout.allPanes[2])
    }
}
