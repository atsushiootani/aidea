//
//  VoiceInputButton.swift
//  Aidea
//

import SwiftUI

/// AppHeader に配置するマイクボタン。アクティブな Claude セッションがあるときだけ有効化される。
/// 起動経路は VoiceInputLauncher に集約され、CommandMenu (⌘ ⌥ V) と共有される。
/// 仕様: docs/specs/frontchannels/voice-input.md
struct VoiceInputButton: View {
    @Environment(SessionRegistry.self) private var registry
    @Environment(CompanionStore.self) private var companionStore

    var body: some View {
        Button {
            VoiceInputLauncher.present(registry: registry, companionStore: companionStore)
        } label: {
            Image(systemName: isEnabled ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 18))
                .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(isEnabled
              ? "音声入力 (⌘ ⌥ V でも起動 / アクティブな Claude セッションへ送信)"
              : "音声入力はアクティブな Claude セッションがあるときに利用できます")
    }

    /// アクティブセッションが Claude セッションであれば true (送信先がある状態)。
    private var isEnabled: Bool {
        (registry.activeSession?.state as? ClaudeSessionState) != nil
    }
}
