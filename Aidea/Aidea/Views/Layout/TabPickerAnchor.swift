//
//  TabPickerAnchor.swift
//  Aidea
//

import AppKit
import Observation

/// Cmd+T のツール選択メニューを「+」ボタンの右下に出すためのアンカー管理。
/// 各 PaneView の「+」ボタン直下に仕込まれた NSView を paneID ごとに弱参照で保持し、
/// AideaApp 側から screen 座標を問い合わせ可能にする。
@Observable
final class TabPickerAnchor {
    /// paneID → 「+」ボタン NSView の弱参照ボックス
    private var anchors: [UUID: WeakBox] = [:]

    /// AddButtonAnchorView から呼ばれる NSView 登録。上書き許容。
    func register(paneID: UUID, view: NSView) {
        anchors[paneID] = WeakBox(view: view)
    }

    /// 明示的な解除 (PaneView が消える際に呼ぶ)。呼び忘れても WeakBox.view が nil になるため致命的ではない。
    func unregister(paneID: UUID) {
        anchors.removeValue(forKey: paneID)
    }

    /// 指定 Pane の「+」ボタン NSView の右下座標 (screen 座標系) を返す。
    /// Window 未 attach や view が解放済なら nil を返す。
    func bottomRightScreenPoint(for paneID: UUID) -> NSPoint? {
        guard let box = anchors[paneID], let view = box.view, let window = view.window else { return nil }
        // NSView は左下原点。「+」ボタンの右下 = (maxX, 0)
        let localBottomRight = NSPoint(x: view.bounds.maxX, y: 0)
        let windowPoint = view.convert(localBottomRight, to: nil)
        let screenRect = window.convertToScreen(NSRect(origin: windowPoint, size: .zero))
        return screenRect.origin
    }

    /// NSView を弱参照で抱えるためのボックス
    private struct WeakBox {
        weak var view: NSView?
    }
}
