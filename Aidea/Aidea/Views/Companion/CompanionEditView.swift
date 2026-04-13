//
//  CompanionEditView.swift
//  Aidea
//

import SwiftUI

/// コンパニオンの編集シート。名前、初期プロンプト、自動起動の設定。
struct CompanionEditView: View {
    @State var companion: CompanionConfig
    let onSave: (CompanionConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // アイコンプレビュー + タイトル
            HStack(spacing: 10) {
                if CompanionIconPresets.isImageIcon(companion.icon) {
                    Image(companion.icon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(companion.name.isEmpty ? "新しいコンパニオン" : companion.name)
                    .font(.headline)
            }

            // 名前
            VStack(alignment: .leading, spacing: 4) {
                Text("名前")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("コンパニオン名", text: $companion.name)
                    .textFieldStyle(.roundedBorder)
            }

            // 初期プロンプト
            VStack(alignment: .leading, spacing: 4) {
                Text("初期プロンプト")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $companion.initialPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 120)
                    .border(Color.secondary.opacity(0.3))
            }

            // ボタン
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    onSave(companion)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(companion.name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
