//
//  VoiceInputDialog.swift
//  Aidea
//

import AppKit
import CoreGraphics

/// 音声入力ダイアログ。NSAlert + NSTextField のシンプルな入力ダイアログで、
/// 表示直後に macOS Dictation のカスタムショートカット (⌘ ⌥ ⇧ V) を CGEvent で
/// 自動起動する。
/// 経緯: 旧仕様は「Control 2 度押し」→「Caps Lock 2 度押し」と試したが、
/// double-tap 検出ロジックが CGEvent.post 経路では一貫して発火しないケースがあった。
/// ユニーク修飾キー組合せ (Cmd+Shift+Opt+V) を 1 回押しだけ送る方式に切り替え、
/// 修飾キーリマップやキー toggle の特殊性に依存しない経路を取る。
/// ユーザは macOS の Dictation 設定で「カスタムショートカット」を ⌘ ⌥ ⇧ V に
/// 割り当てておく必要がある。Aidea 自身のダイアログ起動は ⌘ ⌥ V なので Shift の
/// 有無で衝突しない。
/// 仕様: docs/specs/frontchannels/voice-input.md
enum VoiceInputDialog {

    /// モーダルでダイアログを表示し、ユーザが入力したテキストを返す。
    /// - Parameters:
    ///   - targetName: 送信先のコンパニオン名 (タイトルに表示)。
    ///   - iconImage: ダイアログ左上に表示するアイコン画像。送信先コンパニオンの thumbnail を渡す想定。
    ///     nil または nil 渡し時はアプリアイコンが使われる。
    /// - Returns: trim 後の入力文字列。キャンセル / 空入力なら nil。
    @MainActor
    static func show(targetName: String, iconImage: NSImage? = nil) -> String? {
        let alert = NSAlert()
        alert.messageText = "音声入力"
        alert.informativeText = "\(targetName) に送信します。"
        alert.alertStyle = .informational
        if let iconImage {
            alert.icon = iconImage
        }
        let sendButton = alert.addButton(withTitle: "送信")
        let cancelButton = alert.addButton(withTitle: "キャンセル")
        cancelButton.keyEquivalent = "\u{1b}"

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        textField.placeholderString = "音声で入力するか、テキストを入力してください"
        alert.accessoryView = textField

        // 送信ボタンは空入力で無効化する。textDidChangeNotification でリアルタイム更新。
        let validator = VoiceInputValidator(textField: textField, sendButton: sendButton)
        validator.update()
        let observer = NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification,
            object: textField,
            queue: .main
        ) { _ in
            // queue: .main 指定なので main thread で発火するが、@Sendable closure 型のため
            // MainActor.assumeIsolated で actor isolated な validator.update() を呼ぶ。
            MainActor.assumeIsolated {
                validator.update()
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // 表示直後にテキストフィールドへフォーカスを当て、続けて Dictation の
        // カスタムショートカット (⌘ ⌥ ⇧ V) を CGEvent で POST する。makeFirstResponder 直後だと
        // ウィンドウのフォーカス遷移と競合するため、わずかに遅らせる。
        DispatchQueue.main.async {
            alert.window.makeFirstResponder(textField)
            triggerDictationShortcut()
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    /// macOS Dictation の起動ショートカット (⌘ ⌥ ⇧ V) を CGEvent で 1 度だけ POST する。
    /// ユーザのシステム設定 (キーボード > 音声入力 (Dictation) のショートカット) で
    /// 「カスタムショートカット → ⌘ ⌥ ⇧ V」が設定されている前提。
    /// ショートカットが未設定 / 別キーになっている場合は無効化されるが、ユーザは
    /// 自分の手で Dictation を起動できるので致命的ではない。
    /// double-tap 方式 (Control 2 度 / Caps Lock 2 度) は CGEvent 経路で発火が
    /// 不安定だったため、ユニークな修飾キー組合せの 1 回押しに切り替えている。
    private static func triggerDictationShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09  // V (US 配列の virtual key code)
        let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift]

        if let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            down.flags = modifiers
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            up.flags = modifiers
            up.post(tap: .cghidEventTap)
        }
    }
}

/// VoiceInputDialog の入力テキストを監視し、空のときは送信ボタンを無効化する。
@MainActor
final class VoiceInputValidator {
    private let textField: NSTextField
    private let sendButton: NSButton

    init(textField: NSTextField, sendButton: NSButton) {
        self.textField = textField
        self.sendButton = sendButton
    }

    /// 現在のテキストをチェックして送信ボタンの有効/無効を更新する。
    func update() {
        let trimmed = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        sendButton.isEnabled = !trimmed.isEmpty
    }
}
