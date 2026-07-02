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

    /// スケジューラへの移動 (元削除) 確認ダイアログの表示状態。
    @State private var showPromoteConfirm = false
    /// 削除確認ダイアログの表示状態 (aspects/destructive-actions.md)。
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 1 行目: name
            HStack(spacing: 6) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(snippet.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            // 2 行目: 送信先 / command (スケジューラ行と同じ形式)
            Text("→ \(destinationName) / \(snippet.command)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            // 3 行目: 操作ボタン
            HStack(spacing: 6) {
                runMenu
                Spacer(minLength: 4)
                Button("→ スケジューラ") {
                    showPromoteConfirm = true
                }
                .font(.system(size: 11))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("スケジューラジョブへ移動 (このスニペットは削除されます)")
                .confirmationDialog(
                    "「\(snippet.displayName)」をスケジューラジョブへ移動しますか？\nこのスニペットは削除されます。",
                    isPresented: $showPromoteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("移動", role: .destructive) { promoteToScheduler() }
                    Button("キャンセル", role: .cancel) {}
                }

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("編集")

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.red)
                .help("削除")
                .confirmationDialog(
                    "「\(snippet.displayName)」を削除しますか？",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("削除", role: .destructive) { onDelete() }
                    Button("キャンセル", role: .cancel) {}
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }

    /// 実行ボタン。主アクションは設定済み送信先 (destination) へ即実行。
    /// メニューからはその場限りで別の端末 (アクティブ / 各ターミナル / 新規) を選べる。
    private var runMenu: some View {
        Menu {
            Button("アクティブターミナル") {
                snippetState.run(snippetID: snippet.id, target: .active)
            }
            let terminals = terminalSessions
            if !terminals.isEmpty {
                Divider()
                ForEach(terminals, id: \.id) { session in
                    Button(registry.tabTitle(for: session.id)) {
                        snippetState.run(snippetID: snippet.id, target: .session(session.id))
                    }
                }
            }
            Divider()
            Button("新規ターミナルタブ") {
                snippetState.run(snippetID: snippet.id, target: .new)
            }
        } label: {
            Label("実行", systemImage: "play.fill")
                .font(.system(size: 11, weight: .semibold))
        } primaryAction: {
            // 主ボタン: 設定済み送信先へ即実行 (選ばない)。
            snippetState.run(snippetID: snippet.id)
        }
        // スケジューラの「今すぐ実行」(.bordered) より目立たせる (issue #247):
        // アクセントカラー塗りの prominent ボタン + play アイコン
        .menuStyle(.button)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .fixedSize()
    }

    /// 既定送信先の表示名 (スケジューラ行の送信先表示と揃える)。
    private var destinationName: String {
        switch snippet.destination {
        case .none: return "アクティブ"
        case .tab(let title): return title
        case .new: return "Terminal (新規)"
        }
    }

    private var terminalSessions: [Session] {
        layout.allPanes
            .flatMap { $0.tabs }
            .filter { $0.tool == .terminal }
            .compactMap { registry.session(for: $0) }
    }

    /// スニペットをスケジューラジョブへ「移動」する (元スニペットは削除)。
    private func promoteToScheduler() {
        let sessionTitle: String?
        switch snippet.destination {
        case .tab(let title): sessionTitle = title
        case .new, .none: sessionTitle = nil
        }
        let job = SchedulerConfig.Job(
            id: "snip-" + UUID().uuidString.prefix(8).lowercased(),
            name: snippet.displayName,
            enabled: nil,
            trigger: .manual,
            target: .terminal(sessionTitle: sessionTitle),
            prompt: snippet.command
        )
        schedulerState.addJob(job)
        snippetState.deleteSnippet(snippetID: snippet.id)
    }
}
