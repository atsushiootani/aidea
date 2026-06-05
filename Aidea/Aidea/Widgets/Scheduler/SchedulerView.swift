//
//  SchedulerView.swift
//  Aidea
//

import SwiftUI

/// ヘッダ常駐の定時スケジューラ widget。`WidgetView` 内で `RemindView` の左隣に並ぶ。
/// 時計アイコン + 全ジョブを俯瞰した集約状態 (未実行 N / 次回 HH:mm / 停止中) を表示し、
/// クリックで `SchedulerPopoverView` を開く。状態表示の優先順位は 未実行 > 次回待ち > 全停止。
/// docs/specs/widgets/scheduler.md 参照。
struct SchedulerView: View {
    @Environment(SchedulerState.self) private var scheduler

    var body: some View {
        @Bindable var scheduler = scheduler
        Button {
            scheduler.isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                Text(labelText)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(labelColor)
            .frame(maxWidth: 160, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .popover(isPresented: $scheduler.isPopoverPresented, arrowEdge: .top) {
            SchedulerPopoverView()
        }
    }

    /// ヘッダラベル: 「未実行 N」/「HH:mm」/「停止中」
    private var labelText: String {
        switch scheduler.headerStatus {
        case .overdue(let count): return "未実行 \(count)"
        case .next(let time): return time
        case .idle: return "停止中"
        }
    }

    /// 未実行は警告色 (orange)、それ以外はグレー
    private var labelColor: Color {
        switch scheduler.headerStatus {
        case .overdue: return .orange
        case .next, .idle: return .secondary
        }
    }

    private var helpText: String {
        switch scheduler.headerStatus {
        case .overdue(let count): return "定時スケジューラ: 未実行 \(count) 件 (クリックで手動実行)"
        case .next(let time): return "定時スケジューラ: 次回 \(time)"
        case .idle: return "定時スケジューラ (停止中 / ジョブなし)"
        }
    }
}
