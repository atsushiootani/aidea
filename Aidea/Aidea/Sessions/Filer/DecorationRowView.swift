//
//  DecorationRowView.swift
//  Aidea
//

import AppKit

/// Filer のセル行にデコレーション背景色を塗るための NSTableRowView サブクラス。
/// 選択中の行は AppKit の標準ハイライトを優先し、背景色は描かない。
/// 仕様: `docs/specs/tools/filer.md#デコレーション`
final class DecorationRowView: NSTableRowView {
    /// デコレーションで適用する背景色 (`alpha 0.2` 程度を想定)。`nil` なら塗らない。
    var decorationBackground: NSColor?

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        guard !isSelected, let bg = decorationBackground else { return }
        bg.setFill()
        dirtyRect.fill()
    }
}
