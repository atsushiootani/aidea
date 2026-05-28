//
//  RemindRowView.swift
//  Aidea
//

import SwiftUI

/// `RemindPopoverView` のリスト 1 行ぶん。
/// `HH:mm` (トリガ時刻) + 本文プレビュー + 削除ボタン (`✕`) を横並びで表示する。
/// 削除ボタンは `RemindState.deleteRemind(_:)` を呼び、ファイル削除でキャンセル相当の動作にする。
/// docs/specs/backchannels/remind.md 参照。
struct RemindRowView: View {
    @Environment(RemindState.self) private var remind

    let entry: RemindEntry

    var body: some View {
        HStack(spacing: 8) {
            Text(entry.triggerTimeShort)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 40, alignment: .leading)
            Text(entry.preview)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                remind.deleteRemind(entry)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("削除")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}
