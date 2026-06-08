//
//  SchedulerJobEditView.swift
//  Aidea
//

import SwiftUI

/// `SchedulerPopoverView` 内に展開するジョブの追加 / 編集フォーム。
/// 名前・トリガー (定時/起動時/手動)・送信先 (Claude/Terminal)・prompt・有効を編集し、
/// 保存で `SchedulerState` に反映する。トリガー / 送信先の選択で関連フィールドの表示が切り替わる。
/// docs/specs/widgets/scheduler.md / ADR 0031 参照。
struct SchedulerJobEditView: View {
    /// 編集対象 (新規 or 既存)
    let target: SchedulerPopoverView.EditTarget
    /// 完了 (保存 / キャンセル) 時に popover 側で一覧へ戻すためのコールバック
    let onDone: () -> Void

    @State private var name: String
    @State private var triggerKind: TriggerKind
    @State private var timeDate: Date
    @State private var weekdays: Set<Int>
    @State private var targetKind: TargetKind
    @State private var companionIndex: Int
    @State private var prompt: String
    @State private var enabled: Bool

    @Environment(SchedulerState.self) private var scheduler
    @Environment(CompanionStore.self) private var companionStore

    /// 既存ジョブの id (新規なら nil)。保存時の id 決定に使う。
    private let existingID: String?

    private static let weekdayLabels = ["日", "月", "火", "水", "木", "金", "土"]

    /// トリガー種別 (フォーム用。SchedulerConfig.Trigger を保存時に構築する)
    private enum TriggerKind: CaseIterable {
        case scheduled, onLaunch, manual
        var label: String {
            switch self {
            case .scheduled: return "定時"
            case .onLaunch: return "起動時"
            case .manual: return "手動"
            }
        }
    }

    /// 送信先種別 (フォーム用)
    private enum TargetKind: CaseIterable {
        case claude, terminal
        var label: String {
            switch self {
            case .claude: return "Claude"
            case .terminal: return "Terminal"
            }
        }
    }

    init(target: SchedulerPopoverView.EditTarget, onDone: @escaping () -> Void) {
        self.target = target
        self.onDone = onDone
        switch target {
        case .new:
            existingID = nil
            _name = State(initialValue: "")
            _triggerKind = State(initialValue: .scheduled)
            _timeDate = State(initialValue: Self.date(fromHHmm: "08:00"))
            _weekdays = State(initialValue: Set(0...6))
            _targetKind = State(initialValue: .claude)
            _companionIndex = State(initialValue: 0)
            _prompt = State(initialValue: "")
            _enabled = State(initialValue: true)
        case .existing(let job):
            existingID = job.id
            _name = State(initialValue: job.displayName)
            switch job.trigger {
            case .scheduled(let time, let weekdays):
                _triggerKind = State(initialValue: .scheduled)
                _timeDate = State(initialValue: Self.date(fromHHmm: time))
                _weekdays = State(initialValue: Set(weekdays ?? [0, 1, 2, 3, 4, 5, 6]))
            case .onLaunch:
                _triggerKind = State(initialValue: .onLaunch)
                _timeDate = State(initialValue: Self.date(fromHHmm: "08:00"))
                _weekdays = State(initialValue: Set(0...6))
            case .manual:
                _triggerKind = State(initialValue: .manual)
                _timeDate = State(initialValue: Self.date(fromHHmm: "08:00"))
                _weekdays = State(initialValue: Set(0...6))
            }
            switch job.target {
            case .claude(let index):
                _targetKind = State(initialValue: .claude)
                _companionIndex = State(initialValue: index)
            case .terminal:
                _targetKind = State(initialValue: .terminal)
                _companionIndex = State(initialValue: 0)
            }
            _prompt = State(initialValue: job.prompt)
            _enabled = State(initialValue: job.isEnabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            field("名前") {
                TextField("ジョブ名", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            field("トリガー") {
                Picker("", selection: $triggerKind) {
                    ForEach(TriggerKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            // 時刻・曜日は定時トリガーのときだけ表示する。
            if triggerKind == .scheduled {
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
            }

            field("送信先") {
                Picker("", selection: $targetKind) {
                    ForEach(TargetKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            // Companion ピッカーは Claude 送信のときだけ表示する。
            if targetKind == .claude {
                field("Companion") {
                    Picker("", selection: $companionIndex) {
                        ForEach(0..<companionStore.companions.count, id: \.self) { index in
                            Text("\(index): \(companionStore.companion(forIndex: index).name)").tag(index)
                        }
                    }
                    .labelsHidden()
                }
            }

            field("prompt") {
                TextField(promptPlaceholder, text: $prompt)
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

    /// prompt の placeholder は送信先で変える (Terminal はコマンド例)。
    private var promptPlaceholder: String {
        targetKind == .terminal ? "npm run dev など" : "/cc.morning など"
    }

    /// ラベル + コントロールの 1 行レイアウト。
    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
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

    /// 保存可能か: 名前・prompt が非空。定時トリガーなら曜日が 1 つ以上選択されている。
    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !prompt.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if triggerKind == .scheduled, weekdays.isEmpty { return false }
        return true
    }

    /// フォーム内容から Job を構築し、新規なら addJob / 既存なら updateJob を呼ぶ。
    private func save() {
        let trigger: SchedulerConfig.Trigger
        switch triggerKind {
        case .scheduled:
            trigger = .scheduled(time: Self.hhmm(from: timeDate), weekdays: weekdays.sorted())
        case .onLaunch:
            trigger = .onLaunch
        case .manual:
            trigger = .manual
        }
        let jobTarget: SchedulerConfig.Target
        switch targetKind {
        case .claude:
            jobTarget = .claude(companionIndex: companionIndex)
        case .terminal:
            jobTarget = .terminal
        }
        let job = SchedulerConfig.Job(
            id: existingID ?? Self.makeID(),
            name: name.trimmingCharacters(in: .whitespaces),
            enabled: enabled,
            trigger: trigger,
            target: jobTarget,
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
