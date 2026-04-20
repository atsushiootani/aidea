//
//  ExcludeRulesDialog.swift
//  Aidea
//

import AppKit

/// Filer の除外ルールを編集するモーダルダイアログ。
/// 改行区切りで複数のパターンを編集でき、「デフォルトに戻す」ボタンで `defaults` の内容で上書きできる。
/// OK で編集後のパターン配列を返し、Cancel で nil を返す。
enum ExcludeRulesDialog {

    /// モーダルでダイアログを表示する。
    /// - Parameters:
    ///   - initial: 編集前の除外ルール一覧 (改行区切りでテキストとして提示)
    ///   - defaults: 「デフォルトに戻す」ボタン押下時に充填されるパターン
    /// - Returns: OK で編集後の配列 (空行・前後空白は除去)。Cancel なら nil。
    @MainActor
    static func show(initial: [String], defaults: [String]) -> [String]? {
        let alert = NSAlert()
        alert.messageText = "除外ルール"
        alert.informativeText = "Filer 表示と検索から除外するパターンを 1 行に 1 つずつ入力してください。\n例: node_modules / *.swp / .claude/worktrees"
        alert.alertStyle = .informational
        let okButton = alert.addButton(withTitle: "OK")
        let cancelButton = alert.addButton(withTitle: "キャンセル")
        cancelButton.keyEquivalent = "\u{1b}"
        _ = okButton

        // accessoryView: NSScrollView (複数行入力) + 「デフォルトに戻す」ボタン
        let containerWidth: CGFloat = 360
        let textHeight: CGFloat = 180
        let buttonHeight: CGFloat = 24
        let spacing: CGFloat = 6
        let totalHeight = textHeight + spacing + buttonHeight

        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: totalHeight))

        let scrollView = NSScrollView(frame: NSRect(
            x: 0, y: buttonHeight + spacing,
            width: containerWidth, height: textHeight
        ))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: textHeight))
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.userFixedPitchFont(ofSize: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.string = initial.joined(separator: "\n")
        textView.minSize = NSSize(width: 0, height: textHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        container.addSubview(scrollView)

        // 「デフォルトに戻す」ボタン
        let resetButton = NSButton(frame: NSRect(x: 0, y: 0, width: 140, height: buttonHeight))
        resetButton.title = "デフォルトに戻す"
        resetButton.bezelStyle = .rounded
        let handler = ResetButtonHandler(textView: textView, defaults: defaults)
        resetButton.target = handler
        resetButton.action = #selector(ResetButtonHandler.reset)
        container.addSubview(resetButton)

        alert.accessoryView = container

        // テキストビューに初期フォーカス
        DispatchQueue.main.async {
            alert.window.makeFirstResponder(textView)
        }

        let response = alert.runModal()
        // handler を runModal の生存期間中保持するためのおまじない (ARC 用)
        _ = handler
        if response == .alertFirstButtonReturn {
            return parsePatterns(textView.string)
        }
        return nil
    }

    /// テキストエリアの文字列を改行で分割し、各行を trim、空行を除いた配列を返す
    private static func parsePatterns(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

