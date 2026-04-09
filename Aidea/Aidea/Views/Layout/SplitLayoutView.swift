//
//  SplitLayoutView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// 4 ペインレイアウトを NSSplitViewController で構築するラッパ。
///
/// HSplitView / VSplitView ではペイン幅を API 経由で保存・復元できないため、
/// 代わりに NSSplitView の `autosaveName` を使ってディバイダ位置を
/// UserDefaults に自動保存する。
///
/// 階層:
/// ```
/// 水平分割 (Aidea.splitMain) : left | center | right
///   └ 垂直分割 (Aidea.splitLeft) : topLeft / bottomLeft
/// ```
struct SplitLayoutView: NSViewControllerRepresentable {
    let layout: LayoutConfig
    let workspace: WorkspaceState
    let registry: SessionRegistry

    func makeNSViewController(context: Context) -> NSSplitViewController {
        // --- 左カラム (上下分割) ---
        let leftSplit = NSSplitViewController()
        leftSplit.splitView.isVertical = false // 水平ディバイダで上下に分ける
        leftSplit.splitView.dividerStyle = .thin
        leftSplit.splitView.autosaveName = "Aidea.splitLeft"

        let topLeftItem = NSSplitViewItem(viewController: hosting(pane: layout.topLeft))
        topLeftItem.minimumThickness = 150
        topLeftItem.canCollapse = false

        let bottomLeftItem = NSSplitViewItem(viewController: hosting(pane: layout.bottomLeft))
        bottomLeftItem.minimumThickness = 150
        bottomLeftItem.canCollapse = false

        leftSplit.addSplitViewItem(topLeftItem)
        leftSplit.addSplitViewItem(bottomLeftItem)

        // --- メイン (水平分割: left | center | right) ---
        let main = NSSplitViewController()
        main.splitView.isVertical = true // 垂直ディバイダで左右に分ける
        main.splitView.dividerStyle = .thin
        main.splitView.autosaveName = "Aidea.splitMain"

        let leftItem = NSSplitViewItem(viewController: leftSplit)
        leftItem.minimumThickness = 220
        leftItem.canCollapse = false

        let centerItem = NSSplitViewItem(viewController: hosting(pane: layout.center))
        centerItem.minimumThickness = 400
        centerItem.canCollapse = false

        let rightItem = NSSplitViewItem(viewController: hosting(pane: layout.right))
        rightItem.minimumThickness = 300
        rightItem.canCollapse = false

        main.addSplitViewItem(leftItem)
        main.addSplitViewItem(centerItem)
        main.addSplitViewItem(rightItem)

        return main
    }

    func updateNSViewController(_ controller: NSSplitViewController, context: Context) {
        // Pane は参照型でタブ等の変更は @Observable で追跡されるため、再構築不要
    }

    /// 1 ペイン分の SwiftUI View を NSHostingController に包む
    private func hosting(pane: Pane) -> NSViewController {
        let root = PaneView(pane: pane)
            .environment(workspace)
            .environment(registry)
            .environment(layout)
        return NSHostingController(rootView: root)
    }
}
