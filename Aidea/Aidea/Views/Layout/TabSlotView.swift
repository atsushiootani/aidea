//
//  TabSlotView.swift
//  Aidea
//

import SwiftUI

/// タブバー上の挿入位置を表す View (TabSlot)。
/// 見た目は 4px の縦線 (ホバー時のみアクセントカラー)、ドロップの当たり判定は
/// 左右にパディングを取って 20px 幅で掴みやすくする。
struct TabSlotView: View {
    let pane: Pane
    /// この slot にドロップされたときに挿入される tabs 内のインデックス
    let index: Int
    @Environment(SessionRegistry.self) private var registry
    @State private var isTargeted = false

    var body: some View {
        Color.clear
            .frame(width: 8, height: 22)
            .overlay(
                Rectangle()
                    .fill(isTargeted ? Color.accentColor : Color.clear)
                    .frame(width: 4)
            )
            .contentShape(Rectangle())
            .dropDestination(for: SessionID.self) { items, _ in
                guard let id = items.first else { return false }
                registry.moveSession(id, toPane: pane, atIndex: index)
                return true
            } isTargeted: { isTargeted = $0 }
    }
}
