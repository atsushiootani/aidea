//
//  RemindPopoverView.swift
//  Aidea
//

import SwiftUI

/// `RemindView` から開かれる popover の本体。
/// 未発火のリマインド一覧と、リマインド機能の ON/OFF トグルを表示する。
/// docs/specs/backchannels/remind.md 参照。
struct RemindPopoverView: View {
    @Environment(RemindState.self) private var remind

    var body: some View {
        @Bindable var remind = remind
        VStack(alignment: .leading, spacing: 8) {
            Text("リマインド一覧")
                .font(.headline)

            list

            Divider()

            Toggle(isOn: Binding(
                get: { remind.isEnabled },
                set: { _ in remind.toggle() }
            )) {
                Text("リマインド機能")
                    .font(.body)
            }
            .toggleStyle(.switch)
        }
        .padding(12)
        .frame(width: 320)
    }

    @ViewBuilder
    private var list: some View {
        if !remind.isEnabled {
            placeholderText("リマインド機能は停止中だよ")
        } else if remind.pendingReminds.isEmpty {
            placeholderText("予定なし")
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(remind.pendingReminds) { entry in
                        RemindRowView(entry: entry)
                    }
                }
            }
            .frame(maxHeight: 240)
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
