//
//  SplitLayoutView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// LayoutConfig のツリーを再帰的に NSSplitViewController に展開するラッパ。
/// ツリーが変わるたびに root controller を差し替えて反映する。
struct SplitLayoutView: NSViewControllerRepresentable {
    let layout: LayoutConfig
    let workspace: WorkspaceState
    let registry: SessionRegistry

    func makeNSViewController(context: Context) -> LayoutContainerViewController {
        let container = LayoutContainerViewController()
        container.childController = buildController(for: layout.root)
        context.coordinator.lastSignature = Self.signature(of: layout.root)
        return container
    }

    func updateNSViewController(_ container: LayoutContainerViewController, context: Context) {
        // ツリー構造が変化したら再構築 (divider 位置は autosaveName 経由で復元される)
        let newSignature = Self.signature(of: layout.root)
        if context.coordinator.lastSignature != newSignature {
            container.childController = buildController(for: layout.root)
            context.coordinator.lastSignature = newSignature
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastSignature: String = ""
    }

    /// ツリー構造を識別する文字列 (差分検知用)。
    /// 構造が同じなら再構築をスキップできる。
    private static func signature(of node: LayoutNode) -> String {
        switch node.value {
        case .leaf(let pane):
            return "L[\(pane.id.uuidString)]"
        case .split(let axis, let children):
            let parts = children.map { signature(of: $0) }.joined(separator: ",")
            return "S[\(node.id.uuidString):\(axis.rawValue):\(parts)]"
        }
    }

    /// LayoutNode から再帰的に NSViewController を構築する
    private func buildController(for node: LayoutNode) -> NSViewController {
        switch node.value {
        case .leaf(let pane):
            let root = PaneView(pane: pane, layoutNode: node)
                .environment(workspace)
                .environment(registry)
                .environment(layout)
            return NSHostingController(rootView: root)

        case .split(let axis, let children):
            let splitVC = NSSplitViewController()
            // axis.horizontal = 左右分割 = 垂直ディバイダ = isVertical: true
            splitVC.splitView.isVertical = (axis == .horizontal)
            splitVC.splitView.dividerStyle = .thin
            splitVC.splitView.autosaveName = "Aidea.split.\(node.id.uuidString)"

            for child in children {
                let item = NSSplitViewItem(viewController: buildController(for: child))
                item.minimumThickness = 200
                item.canCollapse = false
                splitVC.addSplitViewItem(item)
            }
            return splitVC
        }
    }
}
