//
//  FileNameInputDialog.swift
//  Aidea
//

import AppKit

/// ファイル名/ディレクトリ名の入力ダイアログ。
/// 入力中にリアルタイムで指定ディレクトリ内の重複をチェックし、
/// 重複時は赤字のエラー表示と OK ボタンの無効化を行う。
enum FileNameInputDialog {

    /// モーダルでダイアログを表示し、入力された名前を返す。
    /// - Parameters:
    ///   - title: ダイアログのタイトル
    ///   - prompt: 補足テキスト
    ///   - initial: 初期値 (rename 時はノードの現在名、create 時は空)
    ///   - parentDirectory: 重複チェックの対象ディレクトリ
    ///   - excludingName: rename 時は自身の名前を重複から除外する
    /// - Returns: 入力された名前。キャンセル / 空入力の場合は nil。
    @MainActor
    static func show(
        title: String,
        prompt: String,
        initial: String,
        parentDirectory: URL,
        excludingName: String? = nil
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = prompt
        alert.alertStyle = .informational
        let okButton = alert.addButton(withTitle: "OK")
        let cancelButton = alert.addButton(withTitle: "キャンセル")
        // Esc でキャンセル
        cancelButton.keyEquivalent = "\u{1b}"

        // accessoryView: テキストフィールド + エラーラベルを縦に並べる
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 48))

        let textField = NSTextField(frame: NSRect(x: 0, y: 22, width: 300, height: 22))
        textField.stringValue = initial
        textField.placeholderString = "名前を入力"
        container.addSubview(textField)

        let errorLabel = NSTextField(labelWithString: "")
        errorLabel.frame = NSRect(x: 0, y: 2, width: 300, height: 16)
        errorLabel.textColor = .systemRed
        errorLabel.font = NSFont.systemFont(ofSize: 11)
        errorLabel.isBordered = false
        errorLabel.drawsBackground = false
        container.addSubview(errorLabel)

        alert.accessoryView = container

        let validator = NameInputValidator(
            textField: textField,
            errorLabel: errorLabel,
            okButton: okButton,
            parentDirectory: parentDirectory,
            excludingName: excludingName
        )
        validator.update()

        let observer = NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification,
            object: textField,
            queue: .main
        ) { _ in
            validator.update()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // テキストフィールドに初期フォーカス
        DispatchQueue.main.async {
            alert.window.makeFirstResponder(textField)
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        return nil
    }
}

/// FileNameInputDialog の入力バリデーションロジック。
/// テキスト変更のたびに呼ばれ、エラー表示と OK ボタンの有効/無効を更新する。
final class NameInputValidator {
    private let textField: NSTextField
    private let errorLabel: NSTextField
    private let okButton: NSButton
    private let parentDirectory: URL
    private let excludingName: String?

    init(
        textField: NSTextField,
        errorLabel: NSTextField,
        okButton: NSButton,
        parentDirectory: URL,
        excludingName: String?
    ) {
        self.textField = textField
        self.errorLabel = errorLabel
        self.okButton = okButton
        self.parentDirectory = parentDirectory
        self.excludingName = excludingName
    }

    /// 現在のテキストをチェックして UI を更新する
    func update() {
        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            errorLabel.stringValue = ""
            okButton.isEnabled = false
            return
        }
        if let excluding = excludingName, name == excluding {
            errorLabel.stringValue = ""
            okButton.isEnabled = true
            return
        }
        let target = parentDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: target.path) {
            errorLabel.stringValue = "同名のファイル・ディレクトリが存在します"
            okButton.isEnabled = false
        } else {
            errorLabel.stringValue = ""
            okButton.isEnabled = true
        }
    }
}
