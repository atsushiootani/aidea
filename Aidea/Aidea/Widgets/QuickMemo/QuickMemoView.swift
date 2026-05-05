//
//  QuickMemoView.swift
//  Aidea
//

import SwiftUI

/// クイックメモの入力パネル。QuickMemoButton の .popover 内に表示する。
/// docs/specs/widgets/quick-memo.md 参照。
struct QuickMemoView: View {
    @Bindable var state: QuickMemoState
    let projectRoot: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("クイックメモ")
                .font(.headline)
            TextEditor(text: $state.draftText)
                .font(.body)
                .frame(width: 280, height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            HStack {
                Spacer()
                Button("キャンセル") {
                    state.dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                Button("保存") {
                    if let root = projectRoot {
                        state.save(to: root)
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(state.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
    }
}
