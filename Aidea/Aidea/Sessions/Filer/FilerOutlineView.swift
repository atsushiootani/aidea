//
//  FilerOutlineView.swift
//  Aidea
//

import AppKit

/// Filer 用にキーボード入力をハンドリングする NSOutlineView サブクラス。
/// `controller` 経由で FileTreeViewController にキー操作を委譲する。
final class FilerOutlineView: NSOutlineView {
    weak var controller: FileTreeViewController?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let controller = controller else {
            super.keyDown(with: event)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shift = flags.contains(.shift)
        let cmd = flags.contains(.command)
        let chars = (event.charactersIgnoringModifiers ?? "").lowercased()

        // Enter (keyCode 36) / Return (keyCode 76 on some keyboards)
        if event.keyCode == 36 || event.keyCode == 76 {
            if shift {
                controller.renameSelectedAction()
            } else {
                controller.previewSelectedAction()
            }
            return
        }

        // Backspace (keyCode 51) / Forward Delete (keyCode 117)
        if event.keyCode == 51 || event.keyCode == 117 {
            controller.deleteSelectedAction()
            return
        }

        // Cmd + N / Cmd + Shift + N
        if cmd, chars == "n" {
            if shift {
                controller.createDirectoryAction()
            } else {
                controller.createFileAction()
            }
            return
        }

        // Cmd + F: 検索バー表示
        if cmd, chars == "f" {
            controller.toggleSearchBar()
            return
        }

        // Esc: 検索バーが開いていれば閉じる (それ以外は super に任せる)
        if event.keyCode == 53 {
            if controller.closeSearchBarIfOpen() {
                return
            }
        }

        super.keyDown(with: event)
    }

    /// 右クリック時にコンテキストメニューを返す。クリックされた行がまだ選択されていなければ選択する。
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        if row >= 0 && !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        return controller?.buildContextMenu()
    }
}
