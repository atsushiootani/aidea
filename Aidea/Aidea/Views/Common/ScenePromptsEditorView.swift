//
//  ScenePromptsEditorView.swift
//  Aidea
//

import SwiftUI

/// Scene のレコメンドプロンプトとデフォルトコンパニオンを編集する SwiftUI View。
/// 左端にデフォルトコンパニオンアイコン、右にプロンプトをタグ風に表示。
struct ScenePromptsEditorView: View {
    let scene: String
    let defaults: [String]
    @Environment(CompanionStore.self) private var companionStore
    @State private var revision: Int = 0  // 変更検知用

    private var prompts: [String] {
        RecommendStore.resolve(scene: scene, defaults: defaults)
    }

    private var defaultCompanionIndex: Int {
        RecommendStore.defaultCompanionIndex(for: scene)
    }

    var body: some View {
        HStack(spacing: 6) {
            // デフォルトコンパニオンアイコン
            companionMenu

            // プロンプトタグ一覧
            let _ = revision  // @State 参照で再描画をトリガー
            ForEach(Array(prompts.enumerated()), id: \.offset) { index, prompt in
                promptTag(prompt, index: index)
            }

            // 追加ボタン
            Button {
                addPrompt()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @State private var showingCompanionPicker = false

    /// デフォルトコンパニオン選択 Popover
    private var companionMenu: some View {
        Button {
            showingCompanionPicker.toggle()
        } label: {
            let icons = CompanionIconPresets.imageIcons
            if defaultCompanionIndex < icons.count {
                Image(CompanionIconPresets.thumbnailIcon(for: icons[defaultCompanionIndex]))
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingCompanionPicker) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(CompanionIconPresets.imageIcons.enumerated()), id: \.offset) { i, icon in
                    Button {
                        RecommendStore.saveDefaultCompanion(scene: scene, index: i)
                        revision += 1
                        showingCompanionPicker = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(CompanionIconPresets.thumbnailIcon(for: icon))
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            Text(companionStore.companion(forIndex: i)?.name ?? "Companion \(i + 1)")
                                .font(.system(size: 11))
                            Spacer()
                            if i == defaultCompanionIndex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
    }

    /// プロンプトタグ
    private func promptTag(_ text: String, index: Int) -> some View {
        HStack(spacing: 2) {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
            Button {
                var current = prompts
                guard index < current.count else { return }
                current.remove(at: index)
                RecommendStore.save(scene: scene, prompts: current)
                revision += 1
            } label: {
                Text("×")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(4)
    }

    /// プロンプト追加ダイアログ
    private func addPrompt() {
        let alert = NSAlert()
        alert.messageText = "プロンプトを追加"
        alert.informativeText = "コンパニオンに送るプロンプトを入力してください"
        alert.addButton(withTitle: "追加")
        alert.addButton(withTitle: "キャンセル")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        alert.accessoryView = input
        if alert.runModal() == .alertFirstButtonReturn, !input.stringValue.isEmpty {
            var current = prompts
            current.append(input.stringValue)
            RecommendStore.save(scene: scene, prompts: current)
            revision += 1
        }
    }
}
