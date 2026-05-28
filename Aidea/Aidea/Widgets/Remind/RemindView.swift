//
//  RemindView.swift
//  Aidea
//

import SwiftUI

/// ヘッダ常駐のリマインドビュー。`WidgetView` 内で `QuickMemoButton` の左隣に並ぶ。
/// カレンダーアイコン + 次予定 1 件のテキストを表示し、クリックで `RemindPopoverView` を開く。
/// docs/specs/backchannels/remind.md 参照。
struct RemindView: View {
    @Environment(RemindState.self) private var remind

    var body: some View {
        @Bindable var remind = remind
        Button {
            remind.isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14))
                Text(labelText)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(labelColor)
            .frame(maxWidth: 200, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(helpText)
        .popover(isPresented: $remind.isPopoverPresented, arrowEdge: .top) {
            RemindPopoverView()
        }
    }

    /// ヘッダに出すラベル: `HH:mm <preview>` / 「（予定なし）」 / 「（停止中）」
    private var labelText: String {
        guard remind.isEnabled else { return "（停止中）" }
        guard let next = remind.nextPending else { return "（予定なし）" }
        return "\(next.triggerTimeShort) \(next.preview)"
    }

    /// 空状態 / OFF はグレー、通常時はアクセントカラー
    private var labelColor: Color {
        guard remind.isEnabled, remind.nextPending != nil else { return .secondary }
        return .accentColor
    }

    private var helpText: String {
        guard remind.isEnabled else { return "リマインド (停止中)" }
        if let next = remind.nextPending {
            return "次のリマインド: \(next.triggerTimeShort)  \(next.preview)"
        }
        return "リマインド (予定なし)"
    }
}
