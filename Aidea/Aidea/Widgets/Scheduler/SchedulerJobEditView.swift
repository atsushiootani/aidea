//
//  SchedulerJobEditView.swift
//  Aidea
//

import SwiftUI

/// `SchedulerPopoverView` 内に展開するジョブの追加 / 編集フォーム。
/// 名前・時刻・曜日・送信先 Companion・prompt・有効を編集し、保存で `SchedulerState` に反映する。
/// 新規 (`.new`) は `addJob`、既存 (`.existing`) は `updateJob` を呼ぶ。
/// docs/specs/widgets/scheduler.md 参照。
struct SchedulerJobEditView: View {
    /// 編集対象 (新規 or 既存)
    let target: SchedulerPopoverView.EditTarget
    /// 完了 (保存 / キャンセル) 時に popover 側で一覧へ戻すためのコールバック
    let onDone: () -> Void

    @State private var name: String
    @State private var timeDate: Date
    @State private var companionIndex: Int
    @State private var prompt: String
    @State private var enabled: Bool
    @State private var weekdays: Set<Int>

    @Environment(SchedulerState.self) private var scheduler
    @Environment(CompanionStore.self) private var companionStore

    /// 既存ジョブの id (新規なら nil)。保存時の id 決定に使う。
    private let existingID: String?

    private static let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    init(target: SchedulerPopoverView.EditTarget, onDone: @escaping () -> Void) {
        self.target = target
        self.onDone = onDone
        switch target {
        case .new:
            existingID = nil
            _name = State(initialValue: "")
            _timeDate = State(initialValue: Self.date(fromHHmm: "08:00"))
            _companionIndex = State(initialValue: 0)
            _prompt = State(initialValue: "")
            _enabled = State(initialValue: true)
            _weekdays = State(initialValue: Set(0...6))
        case .existing(let job):
            existingID = job.id
            _name = State(initialValue: job.displayName)
            _timeDate = State(initialValue: Self.date(fromHHmm: job.time))
            _companionIndex = State(initialValue: job.companionIndex)
            _prompt = State(initialValue: job.prompt)
            _enabled = State(initialValue: job.isEnabled)
            _weekdays = State(initialValue: Set(job.activeWeekdays))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            field("名前") {
                TextField("ジョブ名", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            field("時刻") {
                DatePicker("", selection: $timeDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.field)
            }

            field("曜日") {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { day in
                        weekdayChip(day)
                    }
                }
            }

            field("送信先") {
                Picker("", selection: $companionIndex) {
                    ForEach(0..<companionStore.companions.count, id: \.self) { index in
                        Text("\(index): \(companionStore.companion(forIndex: index).name)").tag(index)
                    }
                }
                .labelsHidden()
            }

            field("prompt") {
                TextField("/cc.morning など", text: $prompt)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("有効", isOn: $enabled)
                .toggleStyle(.switch)
                .controlSize(.small)

            Divider()

            HStack {
                Button("キャンセル", role: .cancel) { onDone() }
                Spacer()
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
        }
    }

    /// ラベル + コントロールの 1 行レイアウト。
    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            content()
        }
    }

    /// 曜日トグルチップ。選択中はアクセント色で塗る。
    private func weekdayChip(_ day: Int) -> some View {
        let selected = weekdays.contains(day)
        return Button {
            if selected { weekdays.remove(day) } else { weekdays.insert(day) }
        } label: {
            Text(Self.weekdayLabels[day])
                .font(.system(size: 11))
                .frame(width: 24, height: 22)
                .background(selected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    /// 保存可能か: 名前・prompt が非空かつ曜日が 1 つ以上選択されている。
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !prompt.trimmingCharacters(in: .whitespaces).isEmpty
            && !weekdays.isEmpty
    }

    /// フォーム内容から Job を構築し、新規なら addJob / 既存なら updateJob を呼ぶ。
    private func save() {
        let job = SchedulerConfig.Job(
            id: existingID ?? Self.makeID(),
            name: name.trimmingCharacters(in: .whitespaces),
            enabled: enabled,
            time: Self.hhmm(from: timeDate),
            weekdays: weekdays.sorted(),
            companionIndex: companionIndex,
            prompt: prompt.trimmingCharacters(in: .whitespaces)
        )
        if existingID == nil {
            scheduler.addJob(job)
        } else {
            scheduler.updateJob(job)
        }
        onDone()
    }

    // MARK: - 時刻変換

    /// "HH:mm" を当日のその時刻の Date に変換する (パース不可なら 08:00)。
    private static func date(fromHHmm string: String) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        let parts = string.split(separator: ":")
        components.hour = parts.count == 2 ? Int(parts[0]) ?? 8 : 8
        components.minute = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
        return calendar.date(from: components) ?? Date()
    }

    /// Date を "HH:mm" 文字列に変換する。
    private static func hhmm(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date)
    }

    /// 新規ジョブの一意 id を生成する。
    private static func makeID() -> String {
        "job-" + UUID().uuidString.prefix(8).lowercased()
    }
}
