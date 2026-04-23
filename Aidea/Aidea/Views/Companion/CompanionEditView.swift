//
//  CompanionEditView.swift
//  Aidea
//

import SwiftUI

/// コンパニオンの編集シート。名前と「指示書を開く」ボタンを持つ。
/// 初期プロンプト本文は v8 以降ファイル化されたため、本シートでは編集せず Preview セッションに委譲する (ADR 0022)。
struct CompanionEditView: View {
    @State var companion: CompanionConfig
    let onSave: (CompanionConfig) -> Void
    let onOpenInstructions: () -> Void
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

            // 指示書 (instructions.md を Preview セッションで開く)
            VStack(alignment: .leading, spacing: 4) {
                Text("指示書")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    onOpenInstructions()
                    dismiss()
                } label: {
                    Label("instructions.md を開く", systemImage: "doc.text")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .help(".aidea/claude/companions/\(companion.index)/instructions.md を Preview タブで開きます")
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
