//
//  VoiceInputDialog.swift
//  Aidea
//

import AppKit
import CoreGraphics

/// 音声入力ダイアログ。NSAlert + NSTextField のシンプルな入力ダイアログで、
/// 表示直後に macOS Dictation (Caps Lock 2 度押し) を CGEvent で自動起動する。
/// 旧仕様は Control 2 度押しだったが、修飾キーリマップ (Ctrl↔CapsLock 入れ替え) が
/// 効いているユーザでは仮想キー 0x3B (Left Control) を POST しても Dictation 側の
/// 検出ルートに刺さらない (CGEvent.post は HID 層直下に出るがリマップは HID より上位で
/// 解釈される)。`Caps Lock 2 度押し` ショートカットなら物理 Caps Lock キーを直接送れて、
/// リマップ設定に依存せず一貫して発火する。
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
        // Caps Lock 2 度押しを CGEvent で POST する。makeFirstResponder 直後だと
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

    /// macOS Dictation の起動ショートカット (Caps Lock キー 2 度押し) を CGEvent で POST する。
    /// ユーザのシステム設定 (キーボード > 音声入力) で「Caps Lock キーを 2 回」になっている前提。
    /// ショートカットが変更されている場合は無効化されるが、ユーザは自分の手で
    /// Dictation を起動できるので致命的ではない。
    /// 2 度押しの間隔は 100ms (macOS Dictation の double-tap 認識窓に収まる範囲)。
    private static func triggerDictationShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let capsLockKeyCode: CGKeyCode = 0x39  // Caps Lock

        // 1 回目の Caps Lock down/up
        postCapsLockTap(source: source, keyCode: capsLockKeyCode)

        // 100ms 後に 2 回目の Caps Lock down/up を POST する
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            postCapsLockTap(source: source, keyCode: capsLockKeyCode)
        }
    }

    /// Caps Lock キーの down + up を 1 ペアで POST する (1 タップ分)。
    /// Caps Lock は通常 toggle 扱いで CGEvent でも flag 管理が特殊なので、
    /// down のときに `.maskAlphaShift` を立てて「Caps Lock 押下中」を再現する。
    /// 修飾キーリマップ (Ctrl↔CapsLock 入れ替え) を行っていても、Dictation の
    /// 「Caps Lock 2 度押し」検出は物理 Caps Lock キー (key code 0x39) のイベント自体を
    /// 監視するため、CGEvent で 0x39 を POST すればリマップに関係なく発火する。
    private static func postCapsLockTap(source: CGEventSource?, keyCode: CGKeyCode) {
        if let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            down.flags = .maskAlphaShift
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            up.flags = []
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
