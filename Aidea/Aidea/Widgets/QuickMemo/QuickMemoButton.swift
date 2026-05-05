//
//  QuickMemoButton.swift
//  Aidea
//

import SwiftUI

/// WidgetView に常駐するクイックメモトリガーボタン。
/// 押下または Cmd+M で QuickMemoView の popover を開く。
/// docs/specs/widgets/quick-memo.md 参照。
struct QuickMemoButton: View {
    @Environment(QuickMemoState.self) private var memoState
    @Environment(WorkspaceState.self) private var workspace

    var body: some View {
        @Bindable var memoState = memoState
        Button {
            if memoState.isPresented {
                memoState.dismiss()
            } else {
                memoState.present()
            }
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 16))
                .foregroundStyle(memoState.isPresented ? Color.accentColor : Color.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("クイックメモ (⌘ M)")
        .popover(isPresented: $memoState.isPresented) {
            QuickMemoView(state: memoState, projectRoot: workspace.projectRoot)
        }
    }
}
