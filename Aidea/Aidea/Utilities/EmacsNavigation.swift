//
//  EmacsNavigation.swift
//  Aidea
//

import AppKit

/// Emacs ライクなキーボードナビゲーションを NSTableView / NSOutlineView に適用するヘルパ。
///
/// - `Ctrl+P`: 上の行へ
/// - `Ctrl+N`: 下の行へ
/// - `Ctrl+F`: (NSOutlineView のとき) 選択ノードを展開
/// - `Ctrl+B`: (NSOutlineView のとき) 選択ノードを折りたたむ
/// - `Ctrl+V`: 1 ページ下へスクロール
/// - `Ctrl+Z`: 1 ページ上へスクロール
///
/// list / tree 系 Session の NSView サブクラスは `keyDown(with:)` 内で
/// `EmacsNavigation.handle(event:table:)` を呼び、true が返ったら super に渡さず return する。
enum EmacsNavigation {

    /// 指定イベントが Emacs バインディングに該当する場合、対応する操作を NSTableView に適用する。
    /// - Parameters:
    ///   - event: キーイベント
    ///   - table: 対象の NSTableView / NSOutlineView
    ///   - allowPageNav: true のとき Ctrl+V/Z のページ送りも処理する (既定 true)。
    ///     ページ送りが不要な Session は false を渡して Ctrl+V/Z を no-op にする。
    /// - Returns: ハンドルした場合 true
    @discardableResult
    static func handle(event: NSEvent, table: NSTableView, allowPageNav: Bool = true) -> Bool {
        let flags = event.modifierFlags
        guard flags.contains(.control),
              !flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.shift) else {
            return false
        }
        let chars = (event.charactersIgnoringModifiers ?? "").lowercased()
        switch chars {
        case "p": moveSelection(table, delta: -1); return true
        case "n": moveSelection(table, delta: 1);  return true
        case "f": expandOrMoveRight(table);         return true
        case "b": collapseOrMoveLeft(table);        return true
        case "v":
            if allowPageNav { scrollPage(table, down: true) }
            return true
        case "z":
            if allowPageNav { scrollPage(table, down: false) }
            return true
        default:  return false
        }
    }

    /// 選択行を上下に移動する
    private static func moveSelection(_ table: NSTableView, delta: Int) {
        let rowCount = table.numberOfRows
        guard rowCount > 0 else { return }
        let current = table.selectedRow
        let next: Int
        if current < 0 {
            next = delta > 0 ? 0 : rowCount - 1
        } else {
            next = max(0, min(rowCount - 1, current + delta))
        }
        table.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        table.scrollRowToVisible(next)
    }

    /// NSOutlineView で選択中のノードを展開する (通常の NSTableView では no-op)
    private static func expandOrMoveRight(_ table: NSTableView) {
        guard let outline = table as? NSOutlineView else { return }
        let row = outline.selectedRow
        guard row >= 0, let item = outline.item(atRow: row) else { return }
        if outline.isExpandable(item) {
            outline.expandItem(item)
        }
    }

    /// NSOutlineView で選択中のノードを折りたたむ (通常の NSTableView では no-op)
    private static func collapseOrMoveLeft(_ table: NSTableView) {
        guard let outline = table as? NSOutlineView else { return }
        let row = outline.selectedRow
        guard row >= 0, let item = outline.item(atRow: row) else { return }
        if outline.isExpandable(item), outline.isItemExpanded(item) {
            outline.collapseItem(item)
        }
    }

    /// スクロールビューを 1 ページ分スクロールする (上下)
    private static func scrollPage(_ table: NSTableView, down: Bool) {
        guard let clip = table.enclosingScrollView?.contentView else { return }
        let pageHeight = clip.bounds.height
        var origin = clip.bounds.origin
        origin.y += down ? pageHeight : -pageHeight
        origin.y = max(0, origin.y)
        clip.scroll(to: origin)
        table.enclosingScrollView?.reflectScrolledClipView(clip)
    }
}
