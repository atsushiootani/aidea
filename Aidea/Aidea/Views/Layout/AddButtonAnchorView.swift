//
//  AddButtonAnchorView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// SwiftUI の `+` ボタン (PaneView.addButton) の背後に透明な NSView を仕込み、
/// 当該 NSView を TabPickerAnchor に登録する。AideaApp の Cmd+T ハンドラが
/// この NSView の右下 screen 座標を読み取り、ツール選択メニューを「+」直下に表示する。
struct AddButtonAnchorView: NSViewRepresentable {
    let paneID: UUID
    let anchor: TabPickerAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // attach 完了直後に登録 (window 取得のため async)
        DispatchQueue.main.async {
            anchor.register(paneID: paneID, view: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // ペイン再構築で新しい NSView になる場合に備えて常に最新を上書き登録
        anchor.register(paneID: paneID, view: nsView)
    }
}
