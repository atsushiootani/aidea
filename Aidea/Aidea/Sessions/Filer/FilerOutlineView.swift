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

    /// クリック時にこの Filer セッションをアクティブにする
    override func mouseDown(with event: NSEvent) {
        controller?.owner?.registry?.activateSession(SessionID(.filer, instance: 0))
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard let controller = controller else {
            super.keyDown(with: event)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shift = flags.contains(.shift)
        let cmd = flags.contains(.command)
        let ctrl = flags.contains(.control)
        let opt = flags.contains(.option)
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

        // Cmd + Shift + G: ナビゲーションメニューを開く
        if cmd, shift, chars == "g" {
            controller.showNavigateMenuFromKeyboard()
            return
        }

        // Cmd + C: コピー / Cmd + V: ペースト
        // (Cmd 単独修飾のときのみ反応。Shift/Ctrl/Opt 同時押しは super に委ねる)
        if cmd, !shift, !ctrl, !opt {
            if chars == "c" {
                controller.copySelectedAction()
                return
            }
            if chars == "v" {
                controller.pasteFromClipboardAction()
                return
            }
        }

        // Esc: 検索バーが開いていれば閉じる (それ以外は super に任せる)
        if event.keyCode == 53 {
            if controller.closeSearchBarIfOpen() {
                return
            }
        }

        // Ctrl+O: Finder で開く / Ctrl+A: 指定のアプリで開く
        // Ctrl+V: ページ下移動 / Ctrl+Z: ページ上移動 (issue #121、selection 追従)
        // (Emacs ナビゲーションより先に判定。Ctrl 単独修飾のときのみ反応させ、
        //  Ctrl+Cmd / Ctrl+Shift / Ctrl+Opt 等の組み合わせは super に委ねる)
        if ctrl, !cmd, !shift, !opt {
            if chars == "o" {
                controller.openInFinderAction()
                return
            }
            if chars == "a" {
                controller.openWithAction()
                return
            }
            if chars == "v" {
                pageMoveSelection(direction: 1)
                return
            }
            if chars == "z" {
                pageMoveSelection(direction: -1)
                return
            }
        }

        // PageDown (keyCode 121) / PageUp (keyCode 116): ページ単位の選択移動 (issue #121)
        if event.keyCode == 121 {
            pageMoveSelection(direction: 1)
            return
        }
        if event.keyCode == 116 {
            pageMoveSelection(direction: -1)
            return
        }

        // Emacs ライクナビゲーション (Ctrl+P/N/F/B)
        // Ctrl+V/Z は Filer 独自拡張 (selection 追従) として上で処理済みのため、
        // EmacsNavigation 側のページ送りは無効化したまま委譲する
        if EmacsNavigation.handle(event: event, table: self, allowPageNav: false) {
            return
        }

        super.keyDown(with: event)
    }

    /// PageUp/PageDown または Ctrl+Z/V によるページ単位の選択移動 (issue #121)
    /// 1 ページ分の行数 (ビュー高さ ÷ 行高さ、最低 1) だけ選択行を進めて scrollRowToVisible する。
    /// 端を超える場合は先頭/末尾で停止し、選択がない状態では PageDown=先頭 / PageUp=末尾を選ぶ。
    /// - Parameter direction: +1 = 下方向、-1 = 上方向
    private func pageMoveSelection(direction: Int) {
        let total = numberOfRows
        guard total > 0 else { return }
        let viewHeight = enclosingScrollView?.contentView.bounds.height ?? bounds.height
        let pageRows = max(1, Int(viewHeight / rowHeight))
        let current = selectedRow
        let next: Int
        if current < 0 {
            next = direction > 0 ? 0 : total - 1
        } else {
            next = max(0, min(total - 1, current + direction * pageRows))
        }
        selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        scrollRowToVisible(next)
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
