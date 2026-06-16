//
//  SnippetEditView.swift
//  Aidea
//

import SwiftUI

/// `SnippetPopoverView` 内に展開するスニペットの追加 / 編集フォーム。
/// name / command / enabled を編集し、保存で SnippetState に反映する。
/// docs/specs/widgets/snippets.md 参照。
struct SnippetEditView: View {
    let target: SnippetPopoverView.EditTarget
    let onDone: () -> Void

    @State private var name: String
    @State private var command: String
    @State private var enabled: Bool

    @Environment(SnippetState.self) private var snippetState

    private let existingID: String?

    init(target: SnippetPopoverView.EditTarget, onDone: @escaping () -> Void) {
        self.target = target
        self.onDone = onDone
        switch target {
        case .new:
            existingID = nil
            _name = State(initialValue: "")
            _command = State(initialValue: "")
            _enabled = State(initialValue: true)
        case .existing(let s):
            existingID = s.id
            _name = State(initialValue: s.displayName)
            _command = State(initialValue: s.command)
            _enabled = State(initialValue: s.isEnabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            field("名前") {
                TextField("スニペット名", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            field("コマンド") {
                TextField("npm run dev など", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }
            Toggle("有効", isOn: $enabled)
                .toggleStyle(.switch)
                .controlSize(.small)
            Divider()
            HStack {
                Button("キャンセル", role: .cancel) { onDone() }
                Spacer()
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            content()
        }
    }

    private func save() {
        let snippet = SnippetConfig.Snippet(
            id: existingID ?? SnippetState.newID(),
            name: name.trimmingCharacters(in: .whitespaces),
            command: command.trimmingCharacters(in: .whitespaces),
            enabled: enabled
        )
        if existingID == nil {
            snippetState.addSnippet(snippet)
        } else {
            snippetState.updateSnippet(snippet)
        }
        onDone()
    }
}
