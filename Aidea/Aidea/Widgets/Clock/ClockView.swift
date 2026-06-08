//
//  ClockView.swift
//  Aidea
//

import SwiftUI

/// WidgetView の右端に現在日時を表示する時計。
/// TimelineView で毎秒更新する。1 行目に日付 `yyyy/MM/dd`、2 行目に曜日 `EEE`、3 行目に時刻 `HH:mm:ss`
/// を出す (例: `2026/06/08` / `Tue` / `12:12:30`)。
/// docs/specs/widgets/clock.md 参照。
struct ClockView: View {
    /// 日付フォーマッタ
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    /// 曜日フォーマッタ (英語曜日 EEE を固定するため en_US_POSIX)
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE"
        return f
    }()

    /// 時刻フォーマッタ
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        // .periodic(by: 1) で毎秒、context.date が更新タイミングの現在時刻を渡す。
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .trailing, spacing: 0) {
                Text(Self.dateFormatter.string(from: context.date))
                Text(Self.weekdayFormatter.string(from: context.date))
                Text(Self.timeFormatter.string(from: context.date))
            }
            .font(.system(size: 10, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .help("現在日時")
        }
    }
}
