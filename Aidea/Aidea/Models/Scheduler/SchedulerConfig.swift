//
//  SchedulerConfig.swift
//  Aidea
//

import Foundation

/// `.aidea/config/scheduler.json` のルート表現。ユーザが宣言的に編集する設定。
/// 各ジョブは trigger (定時/起動時/手動) + target (Claude/Terminal) + prompt を持つ。
/// 旧スキーマ (ジョブ直下に time/weekdays/companionIndex) は scheduled + claude として読む (マイグレーション)。
/// docs/specs/widgets/scheduler.md / ADR 0031 参照。
struct SchedulerConfig: Codable {
    /// スケジュールジョブの配列 (省略時 / ファイル不在は空 = 何も発火しない)
    var jobs: [Job] = []

    /// 実行トリガー。種別ごとに必要なフィールドだけを持つタグ付きユニオン。
    enum Trigger: Equatable {
        /// 定時: `HH:mm` と曜日 (weekdays 省略時は毎日)
        case scheduled(time: String, weekdays: [Int]?)
        /// 周期: cron 式 (`分 時 日 月 曜日`)。壁時計アラインで一致する分ごとに発火。
        case cron(expr: String)
        /// アプリ (リポジトリ) 起動時
        case onLaunch
        /// 手動のみ
        case manual
    }

    /// 送信先。
    enum Target: Equatable {
        /// Claude Companion セッション (companionIndex 0..8)
        case claude(companionIndex: Int)
        /// Terminal タブ。sessionTitle 指定時はその名前のタブへ送る (無ければその名前で新規作成)。
        /// nil / 空のときは名前なしの新規タブ。詳細: ADR 0034。
        case terminal(sessionTitle: String?)
    }

    /// 1 ジョブの設定。`id` をキーに状態ファイルの `lastRun` (定時ジョブのみ) と紐付く。
    struct Job: Codable, Identifiable, Equatable {
        /// ジョブ識別子 (一意・必須)
        let id: String
        /// 表示名 (省略時は id)
        var name: String?
        /// 有効 / 無効 (省略時 true)
        var enabled: Bool?
        /// 実行トリガー
        var trigger: Trigger
        /// 送信先
        var target: Target
        /// 送信するプロンプト / コマンド文字列 (必須)
        let prompt: String

        /// 表示名: name 省略時は id
        var displayName: String { name ?? id }
        /// 有効フラグ: enabled 省略時は true
        var isEnabled: Bool { enabled ?? true }

        /// 定時トリガーの (hour, minute)。scheduled 以外 / パース不可は nil。
        var parsedTime: (hour: Int, minute: Int)? {
            guard case .scheduled(let time, _) = trigger else { return nil }
            let parts = time.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0...23).contains(hour), (0...59).contains(minute) else {
                return nil
            }
            return (hour, minute)
        }

        /// 定時トリガーの発火曜日 (weekdays 省略時は毎日)。scheduled 以外は空配列。
        var activeWeekdays: [Int] {
            guard case .scheduled(_, let weekdays) = trigger else { return [] }
            return weekdays ?? [0, 1, 2, 3, 4, 5, 6]
        }

        /// このジョブが定時トリガーか (Engine のタイマー登録対象判定に使う)。
        var isScheduled: Bool {
            if case .scheduled = trigger { return true }
            return false
        }

        /// このジョブが cron トリガーか。
        var isCron: Bool {
            if case .cron = trigger { return true }
            return false
        }

        /// cron トリガーのパース済み式。cron 以外 / パース不可は nil。
        var cronExpression: CronExpression? {
            guard case .cron(let expr) = trigger else { return nil }
            return CronExpression(expr)
        }

        /// 時刻発火する (タイマー登録対象の) トリガーか。scheduled / cron が該当。
        var isTimed: Bool { isScheduled || isCron }

        /// このジョブが起動時トリガーか (起動時自動実行の対象判定に使う)。
        var isOnLaunch: Bool {
            if case .onLaunch = trigger { return true }
            return false
        }

        var isValid: Bool { validationError == nil }

        /// バリデーション失敗理由 (正常なら nil)。ログ出力用。
        var validationError: String? {
            if id.trimmingCharacters(in: .whitespaces).isEmpty { return "id が空" }
            if prompt.trimmingCharacters(in: .whitespaces).isEmpty { return "prompt が空" }
            if case .scheduled(let time, _) = trigger, parsedTime == nil {
                return "time がパース不可: \"\(time)\""
            }
            if case .cron(let expr) = trigger, CronExpression(expr) == nil {
                return "cron 式がパース不可: \"\(expr)\""
            }
            if case .claude(let index) = target, !(0..<9).contains(index) {
                return "companionIndex 範囲外: \(index)"
            }
            return nil
        }

        /// トリガー種別の表示ラベル (「08:00 毎日」/「起動時」/「手動」)。
        var triggerLabel: String {
            switch trigger {
            case .scheduled:
                guard let t = parsedTime else { return "定時" }
                return String(format: "%02d:%02d ", t.hour, t.minute) + weekdaysLabel
            case .cron(let expr): return expr
            case .onLaunch: return "起動時"
            case .manual: return "手動"
            }
        }

        /// 曜日条件・表示用のラベル (「毎日」/「平日」/「日 月 …」)。定時トリガーのみ意味を持つ。
        var weekdaysLabel: String {
            let days = Set(activeWeekdays)
            if days == Set(0...6) { return "毎日" }
            if days == Set([1, 2, 3, 4, 5]) { return "平日" }
            if days == Set([0, 6]) { return "週末" }
            let names = ["日", "月", "火", "水", "木", "金", "土"]
            return activeWeekdays.sorted()
                .filter { (0...6).contains($0) }
                .map { names[$0] }
                .joined(separator: " ")
        }

        // MARK: - Codable (trigger/target のタグ付きエンコード + 旧スキーマ後方互換)

        enum CodingKeys: String, CodingKey {
            case id, name, enabled, trigger, target, prompt
            // 旧スキーマ (マイグレーション読み込み用)
            case time, weekdays, companionIndex
        }

        init(id: String, name: String?, enabled: Bool?, trigger: Trigger, target: Target, prompt: String) {
            self.id = id
            self.name = name
            self.enabled = enabled
            self.trigger = trigger
            self.target = target
            self.prompt = prompt
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
            prompt = try c.decode(String.self, forKey: .prompt)

            // trigger: 新スキーマ優先。無ければ旧 time/weekdays から scheduled を構築 (マイグレーション)。
            if let t = try c.decodeIfPresent(Trigger.self, forKey: .trigger) {
                trigger = t
            } else if let time = try c.decodeIfPresent(String.self, forKey: .time) {
                let weekdays = try c.decodeIfPresent([Int].self, forKey: .weekdays)
                trigger = .scheduled(time: time, weekdays: weekdays)
            } else {
                // trigger も旧 time も無い → 手動扱い (validation で必要なら弾く)
                trigger = .manual
            }

            // target: 新スキーマ優先。無ければ旧 companionIndex から claude を構築 (マイグレーション)。
            if let tg = try c.decodeIfPresent(Target.self, forKey: .target) {
                target = tg
            } else if let index = try c.decodeIfPresent(Int.self, forKey: .companionIndex) {
                target = .claude(companionIndex: index)
            } else {
                // target も旧 companionIndex も無い → 不正。validation でスキップされる。
                target = .terminal(sessionTitle: nil)
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encodeIfPresent(name, forKey: .name)
            try c.encodeIfPresent(enabled, forKey: .enabled)
            try c.encode(trigger, forKey: .trigger)
            try c.encode(target, forKey: .target)
            try c.encode(prompt, forKey: .prompt)
            // 旧フィールド (time/weekdays/companionIndex) は書かない。常に新スキーマで保存する。
        }
    }

    /// 不正・必須欠落・id 重複のジョブを除外し、有効なジョブのみを返す。
    /// 除外したジョブは NSLog で警告する (他ジョブの動作は止めない)。
    func validJobs() -> [Job] {
        var seen = Set<String>()
        var result: [Job] = []
        for job in jobs {
            if let error = job.validationError {
                NSLog("[Aidea] scheduler job skipped (\(job.id)): \(error)")
                continue
            }
            if seen.contains(job.id) {
                NSLog("[Aidea] scheduler job skipped: id 重複 \"\(job.id)\"")
                continue
            }
            seen.insert(job.id)
            result.append(job)
        }
        return result
    }
}

// MARK: - Trigger / Target の Codable (タグ付きユニオン: type フィールドで分岐)

extension SchedulerConfig.Trigger: Codable {
    private enum CodingKeys: String, CodingKey { case type, time, weekdays, expr }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "scheduled":
            let time = try c.decode(String.self, forKey: .time)
            let weekdays = try c.decodeIfPresent([Int].self, forKey: .weekdays)
            self = .scheduled(time: time, weekdays: weekdays)
        case "cron":
            let expr = try c.decode(String.self, forKey: .expr)
            self = .cron(expr: expr)
        case "onLaunch":
            self = .onLaunch
        case "manual":
            self = .manual
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "未知の trigger type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .scheduled(let time, let weekdays):
            try c.encode("scheduled", forKey: .type)
            try c.encode(time, forKey: .time)
            try c.encodeIfPresent(weekdays, forKey: .weekdays)
        case .cron(let expr):
            try c.encode("cron", forKey: .type)
            try c.encode(expr, forKey: .expr)
        case .onLaunch:
            try c.encode("onLaunch", forKey: .type)
        case .manual:
            try c.encode("manual", forKey: .type)
        }
    }
}

extension SchedulerConfig.Target: Codable {
    private enum CodingKeys: String, CodingKey { case type, companionIndex, sessionTitle }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "claude":
            let index = try c.decode(Int.self, forKey: .companionIndex)
            self = .claude(companionIndex: index)
        case "terminal":
            // sessionTitle 省略 (旧スキーマ含む) は新規タブ扱い。
            let title = try c.decodeIfPresent(String.self, forKey: .sessionTitle)
            self = .terminal(sessionTitle: title)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "未知の target type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .claude(let index):
            try c.encode("claude", forKey: .type)
            try c.encode(index, forKey: .companionIndex)
        case .terminal(let sessionTitle):
            try c.encode("terminal", forKey: .type)
            try c.encodeIfPresent(sessionTitle, forKey: .sessionTitle)
        }
    }
}
