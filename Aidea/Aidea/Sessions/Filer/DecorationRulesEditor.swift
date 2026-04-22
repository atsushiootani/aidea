//
//  DecorationRulesEditor.swift
//  Aidea
//

import AppKit

/// `DecorationRulesDialog` 内の NSTableView の data source / delegate / アクションを担うコントローラ。
/// 編集中のルール配列を `rules` に保持し、OK 確定で外側 (Dialog) が読み取る。
/// 仕様: `docs/specs/tools/filer.md#editdecorationrules--デコレーションルールを編集`
final class DecorationRulesEditor: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    /// テーブル行 D&D 並べ替え用の独自 pasteboard type (Filer 内 D&D とは別経路)
    static let dragType = NSPasteboard.PasteboardType(rawValue: "jp.ruri.aidea.decoration-row")

    /// 編集中のルール配列 (ユーザ追加分のみ。デフォルトは編集対象外)
    var rules: [DecorationRule]
    /// テーブル本体への弱参照 (再描画とサイズ反映用)
    weak var tableView: NSTableView?

    init(initial: [DecorationRule]) {
        self.rules = initial
        super.init()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { rules.count }

    // MARK: - 行 D&D で並べ替え

    /// ドラッグソース: 行 index を pasteboard に書く
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: Self.dragType)
        return item
    }

    /// ドロップターゲット検証: 行と行の間 (`.above`) のみ accept (セル中央へのドロップは禁止)
    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        return dropOperation == .above ? .move : []
    }

    /// ドロップ受け入れ: rules 配列の要素を移動 (順序がマッチング優先順位に直結する)
    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row destRow: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        let pb = info.draggingPasteboard
        guard let str = pb.string(forType: Self.dragType), let srcRow = Int(str) else { return false }
        guard srcRow >= 0, srcRow < rules.count else { return false }
        if srcRow == destRow || srcRow + 1 == destRow { return false }  // no-op
        let movedRule = rules.remove(at: srcRow)
        // 移動元が destRow より前にあった場合は index を 1 詰める
        let adjustedDest = destRow > srcRow ? destRow - 1 : destRow
        let insertAt = max(0, min(adjustedDest, rules.count))
        rules.insert(movedRule, at: insertAt)
        tableView.reloadData()
        return true
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn?.identifier.rawValue else { return nil }
        let rule = rules[row]
        switch column {
        case "pattern":
            let cell = NSTableCellView()
            let field = NSTextField(string: rule.pattern)
            field.isBordered = false
            field.drawsBackground = false
            field.tag = row
            field.target = self
            field.action = #selector(patternEdited(_:))
            field.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(field)
            cell.textField = field
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        case "icon":
            let cell = NSTableCellView()
            let button = NSButton(title: "", target: self, action: #selector(iconButtonClicked(_:)))
            button.bezelStyle = .recessed
            button.tag = row
            if let iconName = rule.icon,
               let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
                    ?? NSImage(named: iconName) {
                button.image = image
                button.title = ""
                button.imagePosition = .imageOnly
            } else {
                button.title = "(なし)"
                button.imagePosition = .noImage
            }
            button.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                button.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                button.heightAnchor.constraint(equalToConstant: 22)
            ])
            return cell
        case "color":
            let cell = NSTableCellView()
            let button = NSButton(title: "", target: self, action: #selector(colorButtonClicked(_:)))
            button.bezelStyle = .recessed
            button.tag = row
            if let bg = DecorationColorPresets.appliedBackground(for: rule.color) {
                button.title = rule.color ?? ""
                button.bezelColor = bg
            } else {
                button.title = "(なし)"
                button.bezelColor = nil
            }
            button.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                button.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                button.heightAnchor.constraint(equalToConstant: 22)
            ])
            return cell
        case "delete":
            let cell = NSTableCellView()
            let button = NSButton(title: "−", target: self, action: #selector(deleteRow(_:)))
            button.bezelStyle = .circular
            button.tag = row
            button.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 22),
                button.heightAnchor.constraint(equalToConstant: 22)
            ])
            return cell
        default:
            return nil
        }
    }

    // MARK: - Actions

    @objc func addRule(_ sender: Any?) {
        rules.append(DecorationRule(pattern: ""))
        tableView?.reloadData()
    }

    @objc private func deleteRow(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < rules.count else { return }
        rules.remove(at: row)
        tableView?.reloadData()
    }

    @objc private func patternEdited(_ sender: NSTextField) {
        let row = sender.tag
        guard row >= 0, row < rules.count else { return }
        rules[row].pattern = sender.stringValue
    }

    @objc private func iconButtonClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < rules.count else { return }
        let menu = NSMenu()
        // NSAlert モーダル中の menu は autoenablesItems の判定で全 item を disable にしてしまうため明示的に切る。
        // ClosureMenuItem は target=self (item 自身) で action を呼ぶため、
        // 一度有効化されれば NSAlert モーダル中でも responder chain に依存せず handler が確実に呼ばれる。
        menu.autoenablesItems = false
        for symbol in DecorationIconPresets.recommended {
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            let item = ClosureMenuItem(title: symbol, image: image) { [weak self] in
                self?.applyIcon(symbol, row: row)
            }
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(ClosureMenuItem(title: "(指定なし)", image: nil as NSImage?) { [weak self] in
            self?.applyIcon(nil, row: row)
        })
        menu.addItem(ClosureMenuItem(title: "その他...", image: nil as NSImage?) { [weak self] in
            self?.promptCustomIcon(row: row)
        })
        Self.popUp(menu: menu, on: sender)
    }

    /// アイコンを適用してテーブルを再描画。
    private func applyIcon(_ name: String?, row: Int) {
        guard row >= 0, row < rules.count else { return }
        rules[row].icon = name
        tableView?.reloadData()
    }

    /// 「その他...」選択時に SF Symbol 名を直接入力させる。
    private func promptCustomIcon(row: Int) {
        guard row >= 0, row < rules.count else { return }
        let alert = NSAlert()
        alert.messageText = "SF Symbol 名を入力"
        alert.informativeText = "例: star.fill / folder.badge.gearshape"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.stringValue = rules[row].icon ?? ""
        alert.accessoryView = input
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "キャンセル")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            rules[row].icon = nil
        } else if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
                || NSImage(named: name) != nil {
            rules[row].icon = name
        } else {
            let warn = NSAlert()
            warn.messageText = "「\(name)」という SF Symbol は見つかりませんでした"
            warn.alertStyle = .warning
            warn.runModal()
            return
        }
        tableView?.reloadData()
    }

    @objc private func colorButtonClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < rules.count else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for entry in DecorationColorPresets.recommended {
            let name = entry.name
            let item = ClosureMenuItem(title: name, image: Self.swatchImage(for: entry.color)) { [weak self] in
                self?.applyColor(name, row: row)
            }
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(ClosureMenuItem(title: "(指定なし)", image: nil as NSImage?) { [weak self] in
            self?.applyColor(nil, row: row)
        })
        menu.addItem(ClosureMenuItem(title: "カスタム...", image: nil as NSImage?) { [weak self] in
            self?.promptCustomColor(row: row)
        })
        Self.popUp(menu: menu, on: sender)
    }

    /// NSAlert モーダル中でも確実に menu の selection event が処理されるよう、
    /// 可能なら `NSMenu.popUpContextMenu(_:with:for:)` (NSEvent ベース) を使う。
    /// `menu.popUp(positioning:at:in:)` 経路は NSAlert モーダル中だと selection 後の
    /// target/action 配信が走らず handler が呼ばれないため避ける。
    /// currentEvent が無い (テスト経路など) ときは view 座標系の `popUp` にフォールバック。
    private static func popUp(menu: NSMenu, on sender: NSView) {
        if let event = NSApplication.shared.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: sender)
        } else {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
        }
    }

    /// 色を適用してテーブルを再描画。
    private func applyColor(_ name: String?, row: Int) {
        guard row >= 0, row < rules.count else { return }
        rules[row].color = name
        tableView?.reloadData()
    }

    /// 「カスタム...」選択時に hex 色を直接入力させる (NSColorPanel から hex を写す想定)。
    private func promptCustomColor(row: Int) {
        guard row >= 0, row < rules.count else { return }
        let panel = NSColorPanel.shared
        panel.color = DecorationColorPresets.resolve(rules[row].color) ?? .systemBlue
        panel.makeKeyAndOrderFront(nil)
        // モーダルではなく、ピッカーで OK ボタンが無いため、シンプルに hex を直接入力する道も用意する
        let alert = NSAlert()
        alert.messageText = "hex 色を入力 (#RRGGBB)"
        alert.informativeText = "NSColorPanel から選んだ色をコピーするか、直接入力してください"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = rules[row].color ?? DecorationColorPresets.hexString(from: panel.color)
        alert.accessoryView = input
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "キャンセル")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let raw = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            rules[row].color = nil
        } else if DecorationColorPresets.resolve(raw) != nil {
            rules[row].color = raw
        } else {
            let warn = NSAlert()
            warn.messageText = "「\(raw)」は無効な色指定です"
            warn.informativeText = "プリセット名 (yellow / blue 等) または hex (#RRGGBB) を入力してください"
            warn.alertStyle = .warning
            warn.runModal()
            return
        }
        tableView?.reloadData()
    }

    /// メニュー項目に表示する色スウォッチ画像を生成
    private static func swatchImage(for color: NSColor) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        color.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 3, yRadius: 3).fill()
        image.unlockFocus()
        return image
    }

}
