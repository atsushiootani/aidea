//
//  QuickMemoButton.swift
//  Aidea
//

import SwiftUI

/// ヘッダ右端に常駐するクイックメモ起動ボタン。
/// 押すと QuickMemoView の popover を開く。
/// docs/specs/widgets/quick-memo.md 参照。
struct QuickMemoButton: View {
    @Environment(QuickMemoState.self) private var quickMemo

    var body: some View {
        @Bindable var quickMemo = quickMemo
        Button {
            quickMemo.togglePresented()
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 16))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("クイックメモ (⌘M)")
        .popover(isPresented: $quickMemo.isPresented) {
            QuickMemoView()
        }
    }
}
