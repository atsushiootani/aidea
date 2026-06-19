//
//  SnippetRowView.swift
//  Aidea
//

import SwiftUI

/// `SnippetPopoverView` のリスト 1 行ぶん。
/// name / command を表示し、実行先を選べる Menu ボタン・編集・削除・
/// スケジューラへの昇格ボタンを置く。docs/specs/widgets/snippets.md 参照。
struct SnippetRowView: View {
    let snippet: SnippetConfig.Snippet
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(SnippetState.self) private var snippetState
    @Environment(SchedulerState.self) private var schedulerState
    @Environment(LayoutConfig.self) private var layout
    @Environment(SessionRegistry.self) private var registry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 1 行目: name + enabled トグル
            HStack(spacing: 6) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(snippet.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Toggle("", isOn: Binding(
                    get: { snippet.isEnabled },
                    set: { _ in toggleEnabled() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
            // 2 行目: command
            Text(snippet.command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            // 3 行目: 操作ボタン
            HStack(spacing: 6) {
                runMenu
                    .disabled(!snippet.isEnabled)
                Spacer(minLength: 4)
                Button("→ スケジューラ") {
                    promoteToScheduler()
                }
                .font(.system(size: 11))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("手動トリガーのスケジューラジョブとして登録")

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("編集")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.red)
                .help("削除")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }

    /// 実行先を選べる Menu ボタン。
    /// アクティブ / 開いている各ターミナル / 新規タブ の 3 種を提示する。
    private var runMenu: some View {
        Menu {
            Button("アクティブターミナル") {
                snippetState.run(snippetID: snippet.id, target: .active)
            }
            let terminals = terminalSessions
            if !terminals.isEmpty {
                Divider()
                ForEach(terminals, id: \.id) { session in
                    Button("Terminal \(session.id.instance + 1)") {
                        snippetState.run(snippetID: snippet.id, target: .session(session.id))
                    }
                }
            }
            Divider()
            Button("新規ターミナルタブ") {
                snippetState.run(snippetID: snippet.id, target: .new)
            }
        } label: {
            Text("実行 ▾")
                .font(.system(size: 11))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var terminalSessions: [Session] {
        layout.allPanes
            .flatMap { $0.tabs }
            .filter { $0.tool == .terminal }
            .compactMap { registry.session(for: $0) }
    }

    private func toggleEnabled() {
        var updated = snippet
        updated.enabled = !snippet.isEnabled
        snippetState.updateSnippet(updated)
    }

    private func promoteToScheduler() {
        let job = SchedulerConfig.Job(
            id: "snip-" + UUID().uuidString.prefix(8).lowercased(),
            name: snippet.displayName,
            enabled: nil,
            trigger: .manual,
            target: .terminal,
            prompt: snippet.command
        )
        schedulerState.addJob(job)
    }
}
