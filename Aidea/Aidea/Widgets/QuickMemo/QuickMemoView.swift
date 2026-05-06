//
//  QuickMemoView.swift
//  Aidea
//

import SwiftUI

/// クイックメモ入力 popover の本体。
/// TextEditor + 保存 / キャンセルボタンで構成する。
/// docs/specs/widgets/quick-memo.md 参照。
struct QuickMemoView: View {
    @Environment(QuickMemoState.self) private var quickMemo
    @Environment(WorkspaceState.self) private var workspace

    @FocusState private var isEditorFocused: Bool

    var body: some View {
        @Bindable var quickMemo = quickMemo
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $quickMemo.memoText)
                .frame(width: 280, height: 120)
                .font(.body)
                .focused($isEditorFocused)
                .overlay(placeholder, alignment: .topLeading)
                .onAppear { isEditorFocused = true }

            HStack {
                Button("キャンセル") {
                    quickMemo.cancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    if let root = workspace.projectRoot {
                        quickMemo.save(projectRoot: root)
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(quickMemo.memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var placeholder: some View {
        if quickMemo.memoText.isEmpty {
            Text("メモを入力...")
                .foregroundStyle(.secondary)
                .font(.body)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .allowsHitTesting(false)
        }
    }
}
