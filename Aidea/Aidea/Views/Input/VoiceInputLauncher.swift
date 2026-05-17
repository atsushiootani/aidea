//
//  VoiceInputLauncher.swift
//  Aidea
//

import AppKit
import AVFoundation

/// 音声入力ダイアログの起動経路を VoiceInputButton と CommandMenu (⌘ ⌥ V) で共有するためのヘルパ。
/// マイク権限確認 → VoiceInputDialog 表示 → sendMessageWhenReady の流れを一箇所にまとめる。
/// 仕様: docs/specs/frontchannels/voice-input.md
enum VoiceInputLauncher {

    /// 現在アクティブな Claude セッションへ音声入力ダイアログを開く。
    /// アクティブセッションが Claude でなければ何もしない (ボタン disabled と同条件)。
    @MainActor
    static func present(registry: SessionRegistry, companionStore: CompanionStore) {
        guard let claudeState = registry.activeSession?.state as? ClaudeSessionState else { return }
        let companion = registry.activeSessionID.flatMap { companionStore.companion(for: $0) }
        let targetName = companion?.name ?? "Claude セッション"
        let iconImage = companion.flatMap { resolveIconImage(for: $0) }

        switch MicrophonePermission.status {
        case .authorized:
            showDialog(targetName: targetName, iconImage: iconImage, claudeState: claudeState)
        case .notDetermined:
            MicrophonePermission.requestIfNeeded { newStatus in
                if newStatus == .authorized {
                    showDialog(targetName: targetName, iconImage: iconImage, claudeState: claudeState)
                } else {
                    MicrophonePermission.showDeniedAlert()
                }
            }
        case .denied, .restricted:
            MicrophonePermission.showDeniedAlert()
        @unknown default:
            MicrophonePermission.showDeniedAlert()
        }
    }

    /// VoiceInputDialog を表示し、入力されたテキストを Claude に送信する。
    /// handoff と同じ `sendMessageWhenReady` 経路で送信し、起動状態の変動に追従する。
    @MainActor
    private static func showDialog(targetName: String, iconImage: NSImage?, claudeState: ClaudeSessionState) {
        guard let message = VoiceInputDialog.show(targetName: targetName, iconImage: iconImage) else { return }
        claudeState.sendMessageWhenReady(message)
    }

    /// CompanionConfig から NSAlert に渡せる NSImage を解決する。
    /// CompanionView と同じ thumbnail バリアントを使い、ダイアログのアイコンを送信先と整合させる。
    private static func resolveIconImage(for companion: CompanionConfig) -> NSImage? {
        let name = CompanionIconPresets.thumbnailIcon(for: companion.icon)
        return NSImage(named: name)
    }
}
