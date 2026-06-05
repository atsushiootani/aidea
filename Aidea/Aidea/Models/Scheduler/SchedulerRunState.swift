//
//  SchedulerRunState.swift
//  Aidea
//

import Foundation

/// `.aidea/state/scheduler.json` のルート表現。自動管理 (ユーザは通常編集しない)。
/// ジョブ `id` → 最後に送信した日付 `YYYY-MM-DD` (ローカル TZ) のマップを持ち、
/// 「本日実行済み」判定 (`lastRun[id] == 今日`) と二重送信防止に使う。
/// docs/specs/widgets/scheduler.md 参照。
struct SchedulerRunState: Codable {
    /// ジョブ id → 最終送信日付 `YYYY-MM-DD`
    var lastRun: [String: String] = [:]

    /// 指定ジョブが `today` (YYYY-MM-DD) に実行済みか
    func isDoneToday(id: String, today: String) -> Bool {
        lastRun[id] == today
    }

    /// 指定ジョブを `today` (YYYY-MM-DD) で実行済みに更新する
    mutating func markDone(id: String, today: String) {
        lastRun[id] = today
    }
}
