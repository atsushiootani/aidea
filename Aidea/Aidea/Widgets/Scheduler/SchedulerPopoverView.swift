//
//  SchedulerPopoverView.swift
//  Aidea
//

import SwiftUI

/// `SchedulerView` から開かれる popover の本体。
/// タイトル「定時スケジューラ」+「＋ 追加」と、登録ジョブ一覧 (`SchedulerRowView`) を表示する。
/// 「＋ 追加」または各行の「編集」を押すと、同じ popover 内に編集フォーム (`SchedulerJobEditView`) を展開する。
/// ジョブが 1 件も無いときは「ジョブなし」プレースホルダを出す。
/// docs/specs/widgets/scheduler.md 参照。
struct SchedulerPopoverView: View {
    /// 編集フォームの対象。nil なら一覧表示。
    @State private var editing: EditTarget?

    @Environment(SchedulerState.self) private var scheduler

    /// 編集フォームが扱う対象 (新規 or 既存ジョブ)。
    enum EditTarget: Identifiable {
        case new
        case existing(SchedulerConfig.Job)

        var id: String {
            switch self {
            case .new: return "__new__"
            case .existing(let job): return job.id
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let editing {
                SchedulerJobEditView(target: editing) {
                    self.editing = nil
                }
            } else {
                list
            }
        }
        .padding(12)
        .frame(width: 400)
    }

    private var header: some View {
        HStack {
            Text("スケジューラ")
                .font(.headline)
            Spacer()
            if editing == nil {
                Button {
                    editing = .new
                } label: {
                    Label("追加", systemImage: "plus")
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        if scheduler.jobs.isEmpty {
            placeholderText("ジョブなし")
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(scheduler.jobs) { job in
                        SchedulerRowView(
                            job: job,
                            onEdit: { editing = .existing(job) },
                            onDelete: { scheduler.deleteJob(jobID: job.id) }
                        )
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }
}
