//
//  RemindView.swift
//  Aidea
//

import SwiftUI

/// ヘッダ常駐のリマインドビュー。`WidgetView` 内で `QuickMemoButton` の左隣に並ぶ。
/// カレンダーアイコン + 直近最大 3 件のテキストを縦並び表示し、クリックで `RemindPopoverView` を開く。
/// 横幅は Pomodoro (`TimerView`) と同じ 146pt を上限とし、超過テキストは末尾 truncate する。
/// docs/specs/backchannels/remind.md 参照。
struct RemindView: View {
    @Environment(RemindState.self) private var remind

    /// ヘッダ占有幅の上限 (Pomodoro `TimerView` の `.frame(width: 146)` と同じ)
    private static let maxLabelWidth: CGFloat = 146

    var body: some View {
        @Bindable var remind = remind
        Button {
            remind.isPopoverPresented.toggle()
        } label: {
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14))
                label
            }
            .foregroundStyle(labelColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: Self.maxLabelWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .popover(isPresented: $remind.isPopoverPresented, arrowEdge: .top) {
            RemindPopoverView()
        }
    }

    /// 状態に応じたラベル: 直近最大 3 件の縦並び / 「（予定なし）」 / 「（停止中）」
    @ViewBuilder private var label: some View {
        if !remind.isEnabled {
            line("（停止中）")
        } else if remind.topPending.isEmpty {
            line("（予定なし）")
        } else {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(remind.topPending) { entry in
                    line("\(entry.triggerTimeShort) \(entry.preview)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 1 行ぶんのテキスト (1 行省略・末尾 truncate)
    private func line(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// 空状態 / OFF はグレー、通常時はアクセントカラー
    private var labelColor: Color {
        guard remind.isEnabled, !remind.topPending.isEmpty else { return .secondary }
        return .accentColor
    }

    private var helpText: String {
        guard remind.isEnabled else { return "リマインド (停止中)" }
        let items = remind.topPending
        guard !items.isEmpty else { return "リマインド (予定なし)" }
        return items.map { "\($0.triggerTimeShort)  \($0.preview)" }.joined(separator: "\n")
    }
}
