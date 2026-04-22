//
//  DecorationRulesDialog.swift
//  Aidea
//

import AppKit

/// Filer のユーザデコレーションルールを編集するモーダルダイアログ。
/// NSTableView ベースの 4 列 (パターン / アイコン / 色 / 削除) エディタ +
/// 「追加」「デフォルトに戻す」ボタンで構成。
/// OK で編集後の `[DecorationRule]` を返し、Cancel で nil を返す。
/// 仕様: `docs/specs/tools/filer.md#editdecorationrules--デコレーションルールを編集`
enum DecorationRulesDialog {

    /// モーダルでダイアログを表示する。
    /// - Parameter initial: 編集前のユーザデコレーションルール
    /// - Returns: OK で編集後の配列。Cancel なら nil。
    @MainActor
    static func show(initial: [DecorationRule]) -> [DecorationRule]? {
        let alert = NSAlert()
        alert.messageText = "デコレーションルール"
        alert.informativeText = "ファイル名/ディレクトリ名のパターンと、それに適用するアイコン (SF Symbol) ・行背景色を指定します。\n後の行ほど優先されます (後勝ち)。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        let cancel = alert.addButton(withTitle: "キャンセル")
        cancel.keyEquivalent = "\u{1b}"

        let containerWidth: CGFloat = 560
        let tableHeight: CGFloat = 240
        let buttonHeight: CGFloat = 24
        let spacing: CGFloat = 6
        let totalHeight = tableHeight + spacing + buttonHeight

        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: totalHeight))

        // テーブル本体
        let scrollView = NSScrollView(frame: NSRect(
            x: 0, y: buttonHeight + spacing,
            width: containerWidth, height: tableHeight
        ))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        let tableView = NSTableView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: tableHeight))
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 26
        tableView.headerView = NSTableHeaderView()

        let patternCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("pattern"))
        patternCol.title = "パターン"
        patternCol.width = 220
        let iconCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("icon"))
        iconCol.title = "アイコン"
        iconCol.width = 80
        let colorCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("color"))
        colorCol.title = "色"
        colorCol.width = 120
        let deleteCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("delete"))
        deleteCol.title = ""
        deleteCol.width = 30
        tableView.addTableColumn(patternCol)
        tableView.addTableColumn(iconCol)
        tableView.addTableColumn(colorCol)
        tableView.addTableColumn(deleteCol)

        let editor = DecorationRulesEditor(initial: initial)
        editor.tableView = tableView
        tableView.dataSource = editor
        tableView.delegate = editor
        // 行 D&D で並べ替え可能にする (順序が後勝ちマッチングの優先順位に直結)
        tableView.registerForDraggedTypes([DecorationRulesEditor.dragType])
        tableView.draggingDestinationFeedbackStyle = .gap

        scrollView.documentView = tableView
        container.addSubview(scrollView)

        // 「+ 追加」ボタン
        let addButton = NSButton(frame: NSRect(x: 0, y: 0, width: 100, height: buttonHeight))
        addButton.title = "+ 追加"
        addButton.bezelStyle = .rounded
        addButton.target = editor
        addButton.action = #selector(DecorationRulesEditor.addRule(_:))
        container.addSubview(addButton)

        alert.accessoryView = container

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 空パターンや前後空白だけの行は除く
            return editor.rules.compactMap { rule in
                let trimmed = rule.pattern.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                return DecorationRule(pattern: trimmed, icon: rule.icon, color: rule.color)
            }
        }
        return nil
    }
}
