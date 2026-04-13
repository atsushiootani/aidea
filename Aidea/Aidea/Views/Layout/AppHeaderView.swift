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
        HStack(spacing: 0) {
            CompanionView()
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let root = workspace.projectRoot {
                speech.start(projectRoot: root)
                store.load(projectRoot: root)
            }
        }
    }
}
