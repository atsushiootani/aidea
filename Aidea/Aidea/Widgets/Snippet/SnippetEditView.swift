//
//  SnippetEditView.swift
//  Aidea
//

import SwiftUI

/// `SnippetPopoverView` 内に展開するスニペットの追加 / 編集フォーム。
/// name / command / destination を編集し、保存で SnippetState に反映する。
/// command は複数行入力 (TextEditor)。docs/specs/widgets/snippets.md 参照。
struct SnippetEditView: View {
    let target: SnippetPopoverView.EditTarget
    let onDone: () -> Void

    @State private var name: String
    @State private var command: String
    @State private var destinationKind: DestinationKind
    @State private var terminalTitle: String

    @Environment(SnippetState.self) private var snippetState
    @Environment(SessionRegistry.self) private var registry
    @Environment(LayoutConfig.self) private var layout

    private let existingID: String?

    /// 送信先種別 (フォーム用)。active は「未設定 (既定)」を表し、保存時は destination = nil。
    private enum DestinationKind: CaseIterable {
        case active, tab, new
        var label: String {
            switch self {
            case .active: return "アクティブ"
            case .tab: return "タブ名"
            case .new: return "新規"
            }
        }
    }

    init(target: SnippetPopoverView.EditTarget, onDone: @escaping () -> Void) {
        self.target = target
        self.onDone = onDone
        switch target {
        case .new:
            existingID = nil
            _name = State(initialValue: "")
            _command = State(initialValue: "")
            _destinationKind = State(initialValue: .active)
            _terminalTitle = State(initialValue: "")
        case .existing(let s):
            existingID = s.id
            _name = State(initialValue: s.displayName)
            _command = State(initialValue: s.command)
            switch s.destination {
            case .none:
                _destinationKind = State(initialValue: .active)
                _terminalTitle = State(initialValue: "")
            case .tab(let title):
                _destinationKind = State(initialValue: .tab)
                _terminalTitle = State(initialValue: title)
            case .new:
                _destinationKind = State(initialValue: .new)
                _terminalTitle = State(initialValue: "")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            field("名前") {
                TextField("スニペット名", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            // コマンドは複数行入力 (issue #247)。高さ約 5 行ぶんの TextEditor。
            field("コマンド", alignment: .top) {
                TextEditor(text: $command)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .frame(height: 96)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }
            field("送信先") {
                Picker("", selection: $destinationKind) {
                    ForEach(DestinationKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            // タブ名入力はタブ名指定のときだけ表示する (選択 + 自由入力)。
            if destinationKind == .tab {
                field("タブ名") {
                    TextField("タブ名", text: $terminalTitle)
                        .textFieldStyle(.roundedBorder)
                }
                field("既存タブ") {
                    HStack(spacing: 4) {
                        ForEach(terminalTabTitles, id: \.self) { title in
                            Button(title) { terminalTitle = title }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
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
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        // タブ名指定のときはタブ名が必須。
        if destinationKind == .tab, terminalTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return true
    }

    /// 現在開いているターミナルタブの表示名一覧 (クイック選択用)。
    private var terminalTabTitles: [String] {
        layout.allPanes
            .flatMap { $0.tabs }
            .filter { $0.tool == .terminal }
            .map { registry.tabTitle(for: $0) }
    }

    private func field<Content: View>(
        _ label: String,
        alignment: VerticalAlignment = .center,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        HStack(alignment: alignment, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            content()
        }
    }

    private func save() {
        let destination: SnippetConfig.Destination?
        switch destinationKind {
        case .active:
            destination = nil
        case .tab:
            destination = .tab(title: terminalTitle.trimmingCharacters(in: .whitespaces))
        case .new:
            destination = .new
        }
        // command は前後の空白・改行だけ落とし、内部の改行 (複数行コマンド) は保持する
        let snippet = SnippetConfig.Snippet(
            id: existingID ?? SnippetState.newID(),
            name: name.trimmingCharacters(in: .whitespaces),
            command: command.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination
        )
        if existingID == nil {
            snippetState.addSnippet(snippet)
        } else {
            snippetState.updateSnippet(snippet)
        }
        onDone()
    }
}
