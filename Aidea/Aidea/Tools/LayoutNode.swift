//
//  LayoutNode.swift
//  Aidea
//

import Foundation
import Observation

/// 動的なペイン配置を表すツリーノード。
/// - `leaf`: 1 つの Pane を保持する末端ノード
/// - `split`: 指定軸で子ノードを並べる分割ノード
@Observable
final class LayoutNode: Identifiable {
    /// ノードの一意識別子。NSSplitView の autosaveName にも使われる。
    let id: UUID
    var value: Value

    enum Value {
        case leaf(Pane)
        case split(axis: Axis, children: [LayoutNode])
    }

    /// 分割の軸
    enum Axis: String, Codable {
        /// 左右分割 (垂直ディバイダで横に並ぶ)
        case horizontal
        /// 上下分割 (水平ディバイダで縦に並ぶ)
        case vertical
    }

    init(id: UUID = UUID(), value: Value) {
        self.id = id
        self.value = value
    }

    /// このノード配下のすべての Pane を収集
    func collectPanes() -> [Pane] {
        switch value {
        case .leaf(let pane):
            return [pane]
        case .split(_, let children):
            return children.flatMap { $0.collectPanes() }
        }
    }

    /// このノード配下のすべての leaf ノードを収集
    func collectLeafNodes() -> [LayoutNode] {
        switch value {
        case .leaf:
            return [self]
        case .split(_, let children):
            return children.flatMap { $0.collectLeafNodes() }
        }
    }
}
