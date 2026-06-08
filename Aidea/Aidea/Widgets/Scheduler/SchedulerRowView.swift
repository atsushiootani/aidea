//
//  SchedulerRowView.swift
//  Aidea
//

import SwiftUI

/// `SchedulerPopoverView` のリスト 1 行ぶん。
/// `name` / トリガー (定時/起動時/手動) / 送信先 (Companion / Terminal) / `prompt` / 実行状態を表示し、
/// 「今すぐ実行」「編集」「削除」ボタンと ON/OFF トグルを置く。
/// docs/specs/widgets/scheduler.md 参照。
struct SchedulerRowView: View {
    let job: SchedulerConfig.Job
    /// 「編集」押下時 (popover 側で編集フォームを開く)
    let onEdit: () -> Void
    /// 「削除」押下時
    let onDelete: () -> Void

    @Environment(SchedulerState.self) private var scheduler
    @Environment(CompanionStore.self) private var companionStore

    var body: some View {
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

                Toggle("", isOn: Binding(
                    get: { job.isEnabled },
                    set: { _ in scheduler.toggle(jobID: job.id) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }

    /// 送信先の表示名 (Claude は Companion 名、Terminal は "Terminal")
    private var targetName: String {
        switch job.target {
        case .claude(let index):
            guard index >= 0, index < companionStore.companions.count else {
                return "Companion \(index + 1)"
            }
            return companionStore.companion(forIndex: index).name
        case .terminal:
            return "Terminal"
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
