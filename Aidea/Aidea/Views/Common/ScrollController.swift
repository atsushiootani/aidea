//
//  ScrollController.swift
//  Aidea
//

import SwiftUI
import AppKit

/// SwiftUI `ScrollView` 内部の NSScrollView をプログラマブルにスクロールさせるためのブリッジ。
///
/// SwiftUI の `ScrollView` には「N ポイントだけスクロール」の直接 API がないため、
/// 透明な NSView を ScrollView の content 内に仕込み、そこから `enclosingScrollView` で
/// 祖先 NSScrollView を掴んで `contentView` の origin を直接操作する。
///
/// 使い方:
/// 1. View に `@State private var scrollController = ScrollController()` を持たせる
/// 2. ScrollView の content の中に `ScrollCommanderView(controller: scrollController).frame(width: 0, height: 0)` を置く
/// 3. `.onKeyPress(.upArrow) { scrollController.scrollBy(-40); return .handled }` などで操作する
final class ScrollController {
    fileprivate weak var target: ScrollCommanderNSView?

    /// dy ポイントだけ縦スクロールする (+ で下、- で上)
    func scrollBy(_ dy: CGFloat) { target?.scrollBy(dy) }

    /// 1 ページ分 (viewport 高さの 90%) 下スクロールする
    func pageDown() { target?.pageScroll(down: true) }

    /// 1 ページ分上スクロールする
    func pageUp() { target?.pageScroll(down: false) }
}

/// `ScrollController` と内部 NSView を接続する NSViewRepresentable。
/// ScrollView の content の中に配置することで、NSView が ScrollView の階層に入る。
struct ScrollCommanderView: NSViewRepresentable {
    let controller: ScrollController

    func makeNSView(context: Context) -> ScrollCommanderNSView {
        let view = ScrollCommanderNSView()
        controller.target = view
        return view
    }

    func updateNSView(_ nsView: ScrollCommanderNSView, context: Context) {
        controller.target = nsView
    }
}

/// 透明な NSView。祖先の NSScrollView を掴んでスクロール命令を実行する。
final class ScrollCommanderNSView: NSView {
    /// dy ポイントだけ縦スクロール。境界を超えない範囲にクランプする。
    func scrollBy(_ dy: CGFloat) {
        guard let scroll = enclosingScrollView else { return }
        let clip = scroll.contentView
        let maxY = max(0, clip.documentRect.height - clip.bounds.height)
        var origin = clip.bounds.origin
        origin.y = max(0, min(maxY, origin.y + dy))
        clip.scroll(to: origin)
        scroll.reflectScrolledClipView(clip)
    }

    /// viewport 高さの 90% を 1 ページぶんとみなしてスクロール
    func pageScroll(down: Bool) {
        guard let scroll = enclosingScrollView else { return }
        let page = scroll.contentView.bounds.height * 0.9
        scrollBy(down ? page : -page)
    }
}
