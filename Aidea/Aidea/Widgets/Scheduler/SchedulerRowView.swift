//
//  SchedulerRowView.swift
//  Aidea
//

import SwiftUI

/// `SchedulerPopoverView` のリスト 1 行ぶん。
/// `name` / トリガー (定時/起動時/手動) / 送信先 (Companion / Terminal) / `prompt` / 実行状態を表示し、
/// 「今すぐ実行」「編集」「削除」ボタンと ON/OFF トグルを置く。
/// 左端の掴みハンドル (≡) のドラッグ & 行へのドロップで並べ替えできる (issue #274)。
/// docs/specs/widgets/scheduler.md 参照。
struct SchedulerRowView: View {
    let job: SchedulerConfig.Job
    /// 「編集」押下時 (popover 側で編集フォームを開く)
    let onEdit: () -> Void
    /// 「削除」押下時
    let onDelete: () -> Void

    @Environment(SchedulerState.self) private var scheduler
    @Environment(SnippetState.self) private var snippetState
    @Environment(CompanionStore.self) private var companionStore

    /// 削除確認ダイアログの表示状態。
    @State private var showDeleteConfirm = false
    /// スニペットへの移動 (元削除) 確認ダイアログの表示状態。
    @State private var showConvertConfirm = false
    /// 並べ替えドラッグのドロップ先としてホバーされているか (アクセント枠の表示用)。
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 6) {
            // 掴みハンドル: ドラッグで並べ替え (issue #274)。ペイロードはジョブ id
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .draggable(job.id)
                .help("ドラッグで並べ替え")

            rowContent
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor, lineWidth: isDropTargeted ? 1.5 : 0)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let sourceID = items.first else { return false }
            scheduler.moveJob(sourceID: sourceID, to: job.id)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 1 行目: 状態アイコン + name + トリガー (定時 HH:mm 曜日 / 起動時 / 手動)
            HStack(spacing: 6) {
                statusIcon
                Text(job.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(job.triggerLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            // 2 行目: 送信先 (Companion 名 / Terminal) / prompt
            Text("→ \(targetName) / \(job.prompt)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            // 3 行目: 実行状態 + 操作
            HStack(spacing: 6) {
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(statusColor)
                Spacer(minLength: 4)
                Button("今すぐ実行") {
                    scheduler.runNow(jobID: job.id)
                }
                .font(.system(size: 11))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!job.isEnabled)

                Button("→ スニペット") {
                    showConvertConfirm = true
                }
                .font(.system(size: 11))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("スニペットへ移動 (このジョブは削除されます)")
                .confirmationDialog(
                    "「\(job.displayName)」をスニペットへ移動しますか？\nこのジョブは削除されます。",
                    isPresented: $showConvertConfirm,
                    titleVisibility: .visible
                ) {
                    Button("移動", role: .destructive) { saveAsSnippet() }
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
                    "「\(job.displayName)」を削除しますか？",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("削除", role: .destructive) { onDelete() }
                    Button("キャンセル", role: .cancel) {}
                }

                Toggle("", isOn: Binding(
                    get: { job.isEnabled },
                    set: { _ in scheduler.toggle(jobID: job.id) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
        }
    }

    /// ジョブをスニペットへ「移動」する (元ジョブは削除)。
    private func saveAsSnippet() {
        let destination: SnippetConfig.Destination?
        switch job.target {
        case .terminal(let sessionTitle):
            if let title = sessionTitle, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                destination = .tab(title: title)
            } else {
                destination = .new // スケジューラの「新規タブ」を踏襲
            }
        case .claude:
            destination = nil // スニペットは Claude 送信を持たない → 既定 (アクティブ端末)
        }
        let snippet = SnippetConfig.Snippet(
            id: "job-" + UUID().uuidString.prefix(8).lowercased(),
            name: job.displayName,
            command: job.prompt,
            destination: destination
        )
        snippetState.addSnippet(snippet)
        scheduler.deleteJob(jobID: job.id)
    }

    /// 送信先の表示名 (Claude は Companion 名、Terminal はタブ名 / 新規)
    private var targetName: String {
        switch job.target {
        case .claude(let index):
            guard index >= 0, index < companionStore.companions.count else {
                return "Companion \(index + 1)"
            }
            return companionStore.companion(forIndex: index).name
        case .terminal(let sessionTitle):
            if let title = sessionTitle, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                return title
            }
            return "Terminal (新規)"
        }
    }

    /// 状態アイコン: 定時の 未実行⚠ / 実行済み✓ / それ以外はトリガー種別アイコン。
    @ViewBuilder
    private var statusIcon: some View {
        if scheduler.isOverdue(jobID: job.id) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
        } else if scheduler.isDoneToday(jobID: job.id) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
        } else {
            Image(systemName: triggerIcon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    /// トリガー種別の SF Symbol
    private var triggerIcon: String {
        switch job.trigger {
        case .scheduled: return "clock"
        case .cron: return "timer"
        case .onLaunch: return "bolt"
        case .manual: return "hand.tap"
        }
    }

    private var statusText: String {
        if scheduler.isOverdue(jobID: job.id) { return "本日 未実行" }
        if scheduler.isDoneToday(jobID: job.id) { return "本日 実行済み" }
        if !job.isEnabled { return "停止中" }
        switch job.trigger {
        case .scheduled: return "待機中"
        case .cron: return "周期実行"
        case .onLaunch: return "起動時に実行"
        case .manual: return "手動実行のみ"
        }
    }

    private var statusColor: Color {
        if scheduler.isOverdue(jobID: job.id) { return .orange }
        if scheduler.isDoneToday(jobID: job.id) { return .green }
        return .secondary
    }
}
