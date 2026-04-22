//
//  TabSlotView.swift
//  Aidea
//

import SwiftUI

/// タブバー上の挿入位置を表す View (TabSlot)。
/// 見た目は 4px の縦線 (ホバー時のみアクセントカラー)、ドロップの当たり判定は
/// 横 12pt × 高さ 22pt で掴みやすくする。
///
/// 2 種類の drop を受け付ける:
/// - `SessionID`: 既存タブをこの slot に移動 (`SessionRegistry.moveSession`)
/// - `URL` (ファイルのみ): この slot に新規 Preview タブを作成 (`SessionRegistry.openPreviewAtSlot`)
struct TabSlotView: View {
    let pane: Pane
    /// この slot にドロップされたときに挿入される tabs 内のインデックス
    let index: Int
    @Environment(SessionRegistry.self) private var registry
    @State private var isTargetedSession = false
    @State private var isTargetedURL = false

    private var isTargeted: Bool { isTargetedSession || isTargetedURL }

    var body: some View {
        Color.clear
            .frame(width: 12, height: 22)
            .overlay(
                Rectangle()
                    .fill(isTargeted ? Color.accentColor : Color.clear)
                    .frame(width: 4)
            )
            // AppKit ベースで NSOutlineView 由来のファイル URL drag を直接受け取る overlay。
            // SwiftUI の dropDestination/onDrop ではこの drag が取りこぼされる。
            .overlay(
                TabSlotURLDropTarget(
                    onEnter: { isTargetedURL = true },
                    onExit: { isTargetedURL = false },
                    onDrop: { urls in
                        let files = urls.filter { !Self.isDirectory($0) }
                        for (offset, url) in files.enumerated() {
                            registry.openPreviewAtSlot(for: url, pane: pane, index: index + offset)
                        }
                    }
                )
            )
            .contentShape(Rectangle())
            .dropDestination(for: SessionID.self) { items, _ in
                guard let id = items.first else { return false }
                registry.moveSession(id, toPane: pane, atIndex: index)
                return true
            } isTargeted: { isTargetedSession = $0 }
    }

    /// ドロップ対象 URL がディレクトリかどうかを判定する
    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}
