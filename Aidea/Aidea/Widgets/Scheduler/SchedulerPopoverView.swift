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

            if !scheduler.isTrusted {
                untrustedBanner
            }

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
        // popover を開くたびに設定・状態ファイルを再読込する (issue #274)。
        // 外部編集 (手編集 / Claude による編集) が再起動なしで反映される。開いている間は再読込しない。
        .onAppear { scheduler.reloadFromDisk() }
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

    /// 設定ファイルが未承認のときの案内 (issue #293)。承認するまで自動発火も「今すぐ実行」もしない。
    private var untrustedBanner: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.shield")
                .foregroundStyle(.orange)
            Text("このワークスペースのジョブ設定は未承認のため、自動実行を止めています。")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("内容を確認…") {
                scheduler.requestTrustIfNeeded()
            }
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
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
