//
//  FocusCatcherView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// 純 SwiftUI コンテンツに対して First Responder を提供するための透明な NSView ラッパ。
///
/// SwiftUI の ScrollView や VStack は自前で First Responder を持てないため、
/// Session の focusableView に何も報告できず、タブ切替時に前のタブが
/// キー入力を握り続ける問題が起きる。
///
/// このビューを `.background()` として配置すると、FocusCatcherNSView が
/// First Responder を引き受けて前のタブからキーフォーカスを奪い取る。
struct FocusCatcherView: NSViewRepresentable {
    /// NSView が生成されたときに呼ばれる (focusableView 報告用)
    let onViewCreated: (NSView) -> Void

    func makeNSView(context: Context) -> FocusCatcherNSView {
        let view = FocusCatcherNSView()
        onViewCreated(view)
        return view
    }

    func updateNSView(_ nsView: FocusCatcherNSView, context: Context) {}
}

/// First Responder を引き受ける透明な NSView。
/// キーイベントは super に渡す (ビープ音を鳴らさないよう noResponderFor をオーバーライド)。
final class FocusCatcherNSView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // 親の NSScrollView 等が拾えるよう super に渡す
        super.keyDown(with: event)
    }

    override func noResponder(for eventSelector: Selector) {
        // ビープ音を鳴らさない (未処理キーでシステムビープが鳴るのを抑制)
    }
}
