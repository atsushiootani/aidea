//
//  AppHeaderView.swift
//  Aidea
//

import SwiftUI

/// アプリ上部のヘッダ。アプリアイコンと読み上げ ON/OFF トグルを配置する。
struct AppHeaderView: View {
    @Environment(SpeechState.self) private var speech
    @Environment(WorkspaceState.self) private var workspace

    var body: some View {
        HStack(spacing: 8) {
            // アプリアイコン
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)

            // 読み上げトグルボタン
            Button {
                speech.toggle()
            } label: {
                Image(systemName: speech.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(speech.isEnabled ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(speech.isEnabled ? "読み上げ OFF" : "読み上げ ON")

            // 再生中インジケータ
            if speech.queue.isSpeaking {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                    .symbolEffect(.variableColor.iterative)
            }

            // ステータスメッセージ
            if !speech.statusMessage.isEmpty {
                Text(speech.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let root = workspace.projectRoot {
                speech.start(projectRoot: root)
            }
        }
    }
}
