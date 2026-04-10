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
/// 矢印キーや Ctrl+P/N でスクロール、ビープ音を鳴らさないよう noResponderFor をオーバーライド。
final class FocusCatcherNSView: NSView {
    override var acceptsFirstResponder: Bool { true }

    /// スクロール量 (ポイント)
    private static let lineScrollAmount: CGFloat = 40
    private static let pageScrollRatio: CGFloat = 0.9

    override func keyDown(with event: NSEvent) {
        // 矢印キーでスクロール
        switch event.keyCode {
        case 126: // ↑
            scrollBy(-Self.lineScrollAmount)
            return
        case 125: // ↓
            scrollBy(Self.lineScrollAmount)
            return
        default:
            break
        }

        // Ctrl+P/N/V/Z (Emacs ライクナビゲーション)
        let flags = event.modifierFlags
        if flags.contains(.control),
           !flags.contains(.command),
           !flags.contains(.option),
           !flags.contains(.shift) {
            let chars = (event.charactersIgnoringModifiers ?? "").lowercased()
            switch chars {
            case "p": scrollBy(-Self.lineScrollAmount); return
            case "n": scrollBy(Self.lineScrollAmount); return
            case "v": scrollByPage(down: true); return
            case "z": scrollByPage(down: false); return
            default: break
            }
        }

        // 未処理キーは super に渡す (noResponder で握りつぶすのでビープなし)
        super.keyDown(with: event)
    }

    override func noResponder(for eventSelector: Selector) {
        // ビープ音を鳴らさない (未処理キーでシステムビープが鳴るのを抑制)
    }

    /// 指定ポイント数だけ縦スクロールする
    private func scrollBy(_ delta: CGFloat) {
        guard let scrollView = findEnclosingScrollView() else { return }
        let clip = scrollView.contentView
        var origin = clip.bounds.origin
        origin.y += delta
        origin.y = max(0, origin.y)
        clip.scroll(to: origin)
        scrollView.reflectScrolledClipView(clip)
    }

    /// 1 ページ分スクロールする
    private func scrollByPage(down: Bool) {
        guard let scrollView = findEnclosingScrollView() else { return }
        let clip = scrollView.contentView
        let pageAmount = clip.bounds.height * Self.pageScrollRatio
        scrollBy(down ? pageAmount : -pageAmount)
    }

    /// superview チェーンを遡って最も近い NSScrollView を探す
    private func findEnclosingScrollView() -> NSScrollView? {
        var current: NSView? = self
        while let parent = current?.superview {
            if let scroll = parent as? NSScrollView {
                return scroll
            }
            current = parent
        }
        return nil
    }
}
