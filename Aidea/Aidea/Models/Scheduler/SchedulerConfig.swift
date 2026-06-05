//
//  SchedulerConfig.swift
//  Aidea
//

import Foundation

/// `.aidea/config/scheduler.json` のルート表現。ユーザが宣言的に編集する設定。
/// `jobs[]` に「時刻 + 曜日 + 送信先 Companion + プロンプト」を持つジョブを並べる。
/// 既定値補完 (name/enabled/weekdays 省略時) と不正値スキップは Job 側のアクセサ・validate で行う。
/// docs/specs/widgets/scheduler.md 参照。
struct SchedulerConfig: Codable {
    /// スケジュールジョブの配列 (省略時 / ファイル不在は空 = 何も発火しない)
    var jobs: [Job] = []

    /// 1 ジョブの設定。`id` をキーに状態ファイルの `lastRun` と紐付く。
    /// optional フィールド (name/enabled/weekdays) は省略可能で、`displayName` 等のアクセサで既定値を補完する。
    struct Job: Codable, Identifiable, Equatable {
        /// ジョブ識別子 (一意・必須)。状態ファイルのキー / 重複送信判定に使う
        let id: String
        /// 表示名 (省略時は id を使う)
        var name: String?
        /// 有効 / 無効 (省略時 true)
        var enabled: Bool?
        /// 発火時刻 `HH:mm` (ローカル TZ・必須)
        let time: String
        /// 発火曜日 (0=日 〜 6=土。省略時は毎日 [0...6])
        var weekdays: [Int]?
        /// 送信先 Companion index (0..8・必須)
        let companionIndex: Int
        /// 送信するプロンプト文字列 (必須)。スラッシュコマンドでも任意の指示文でもよい
        let prompt: String

        /// 表示名: name 省略時は id を使う
        var displayName: String { name ?? id }
        /// 有効フラグ: enabled 省略時は true
        var isEnabled: Bool { enabled ?? true }
        /// 発火曜日: weekdays 省略時は毎日
        var activeWeekdays: [Int] { weekdays ?? [0, 1, 2, 3, 4, 5, 6] }

        /// `time` をパースして (hour, minute) を返す。`HH:mm` 形式でなければ nil。
        var parsedTime: (hour: Int, minute: Int)? {
            let parts = time.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0...23).contains(hour), (0...59).contains(minute) else {
                return nil
            }
            return (hour, minute)
        }

        /// このジョブが有効値を持つか (time パース可・index 範囲内・id/command 非空)。
        /// 不正なら理由つきで false を返す呼び出し側でログを出す。
        var isValid: Bool { validationError == nil }

        /// バリデーション失敗理由 (正常なら nil)。ログ出力用。
        var validationError: String? {
            if id.trimmingCharacters(in: .whitespaces).isEmpty { return "id が空" }
            if parsedTime == nil { return "time がパース不可: \"\(time)\"" }
            if !(0..<9).contains(companionIndex) { return "companionIndex 範囲外: \(companionIndex)" }
            if prompt.trimmingCharacters(in: .whitespaces).isEmpty { return "prompt が空" }
            return nil
        }

        /// 曜日条件・表示用のラベル (「毎日」/「平日」/「日 月 …」)。
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
    }

    /// 不正・必須欠落・id 重複のジョブを除外し、有効なジョブのみを返す。
    /// 除外したジョブは NSLog で警告する (他ジョブの動作は止めない)。
    /// docs/specs/widgets/scheduler.md「不正値は警告ログを出し当該ジョブをスキップ」準拠。
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
