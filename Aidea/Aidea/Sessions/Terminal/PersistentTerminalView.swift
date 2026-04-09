//
//  PersistentTerminalView.swift
//  Aidea
//

import AppKit
import SwiftTerm

/// SwiftTerm の LocalProcessTerminalView を拡張して、
/// ペイン間移動時の detach/reattach による一時的な frame = 0 状態で
/// バッファがクリアされるのを防ぐ。
///
/// SwiftUI の ZStack から別の ZStack に NSView が移動する間、一瞬だけ
/// superview が nil になる or bounds が 0 になる。このとき SwiftTerm は
/// レイアウトを走らせてターミナルの cols/rows を 0 に resize し、
/// その結果 Main バッファの可視行をクリアしてしまう。
///
/// 極小 bounds ではレイアウトをスキップすることでこの挙動を回避する。
final class PersistentTerminalView: LocalProcessTerminalView {
    /// レイアウトをスキップする閾値 (ポイント)
    private static let minimumLayoutSize: CGFloat = 10

    override func layout() {
        if bounds.width < Self.minimumLayoutSize || bounds.height < Self.minimumLayoutSize {
            return
        }
        super.layout()
    }

    /// フレームが極小になるタイミング (detach 中など) で SwiftTerm に小さな
    /// フレームが伝わると cols/rows が 0 にリサイズされてバッファが消える。
    /// 小さなフレームは無視して前回サイズを維持する。
    override func setFrameSize(_ newSize: NSSize) {
        if newSize.width < Self.minimumLayoutSize || newSize.height < Self.minimumLayoutSize {
            return
        }
        super.setFrameSize(newSize)
    }

    override func setBoundsSize(_ newSize: NSSize) {
        if newSize.width < Self.minimumLayoutSize || newSize.height < Self.minimumLayoutSize {
            return
        }
        super.setBoundsSize(newSize)
    }
}
