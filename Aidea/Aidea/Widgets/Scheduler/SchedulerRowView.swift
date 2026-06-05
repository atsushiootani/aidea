//
//  SchedulerRowView.swift
//  Aidea
//

import SwiftUI

/// `SchedulerPopoverView` のリスト 1 行ぶん。
/// `name` / `time` / 曜日 / 送信先 Companion 名 / `prompt` / 本日の実行状態を表示し、
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
            // 1 行目: 状態アイコン + name + time + 曜日
            HStack(spacing: 6) {
                statusIcon
                Text(job.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(job.time)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Text(job.weekdaysLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // 2 行目: 送信先 Companion / prompt
            Text("→ \(companionName) / \(job.prompt)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            // 3 行目: 本日状態 + 操作
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

    /// 送信先 Companion 名 (index 範囲外なら "Companion N")
    private var companionName: String {
        let index = job.companionIndex
        guard index >= 0, index < companionStore.companions.count else {
            return "Companion \(index + 1)"
        }
        return companionStore.companion(forIndex: index).name
    }

    /// 状態アイコン: 未実行 ⚠ (orange) / 実行済み ✓ (green) / 待機 (grey clock)
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
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        if scheduler.isOverdue(jobID: job.id) { return "本日 未実行" }
        if scheduler.isDoneToday(jobID: job.id) { return "本日 実行済み" }
        if !job.isEnabled { return "停止中" }
        return "待機中"
    }

    private var statusColor: Color {
        if scheduler.isOverdue(jobID: job.id) { return .orange }
        if scheduler.isDoneToday(jobID: job.id) { return .green }
        return .secondary
    }
}
