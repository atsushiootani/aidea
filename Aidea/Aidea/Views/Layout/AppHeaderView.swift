//
//  AppHeaderView.swift
//  Aidea
//

import SwiftUI

/// アプリ上部のヘッダ。今後他のビューも追加予定。
struct AppHeaderView: View {
    @Environment(SpeechState.self) private var speech
    @Environment(WorkspaceState.self) private var workspace
    @Environment(CompanionStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            CompanionView()
            speechToggleButton
            Spacer()
            WidgetView()
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

    /// 読み上げ ON/OFF トグル (issue #128)。コンパニオンビューの直右に配置し、
    /// クリックで `SpeechState.toggle()` を呼ぶ。アイコンは `isEnabled` を見て
    /// `speaker.wave.2.fill` / `speaker.slash.fill` を切り替える。
    private var speechToggleButton: some View {
        Button {
            speech.toggle()
        } label: {
            Image(systemName: speech.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 18))
                .foregroundStyle(speech.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(speech.isEnabled ? "読み上げ ON (クリックで OFF)" : "読み上げ OFF (クリックで ON)")
    }
}
