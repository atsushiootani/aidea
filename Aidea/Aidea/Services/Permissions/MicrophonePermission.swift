//
//  MicrophonePermission.swift
//  Aidea
//

import AppKit
import AVFoundation

/// マイク (TCC) 権限の状態確認・要求・拒否時の誘導を担うヘルパ。
/// 音声入力ダイアログ (`VoiceInputDialog`) から呼ばれ、macOS Dictation を使うために
/// `NSMicrophoneUsageDescription` の TCC ダイアログ発火 / 拒否時のシステム設定誘導を集約する。
/// 仕様: docs/specs/frontchannels/voice-input.md
enum MicrophonePermission {

    /// マイク権限の現在ステータスを取得する。
    static var status: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// 権限を要求する (.notDetermined のときだけ TCC ダイアログを出す)。
    /// 既に決まっている場合は現状値で即座に completion を呼ぶ。
    /// completion は **メインスレッド**で呼ばれる。
    @MainActor
    static func requestIfNeeded(completion: @escaping @MainActor (AVAuthorizationStatus) -> Void) {
        let current = status
        switch current {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async {
                    completion(status)
                }
            }
        default:
            completion(current)
        }
    }

    /// 拒否済みユーザ向けに「設定を開く」alert を表示する。
    /// ユーザが「設定を開く」を選んだ場合はシステム設定のマイクペインを開く。
    @MainActor
    static func showDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "マイクへのアクセスが許可されていません"
        alert.informativeText = "音声入力を使うにはシステム設定でマイクのアクセスを許可してください。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "設定を開く")
        let cancel = alert.addButton(withTitle: "キャンセル")
        cancel.keyEquivalent = "\u{1b}"

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
