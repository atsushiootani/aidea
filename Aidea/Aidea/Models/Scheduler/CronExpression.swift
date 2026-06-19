//
//  CronExpression.swift
//  Aidea
//

import Foundation

/// 標準 5 フィールド cron 式 (`分 時 日 月 曜日`) の最小サブセットパーサ。
/// スケジューラの `cron` トリガー ([ADR 0034](docs/decisions/0034-scheduler-snippet-dispatch.md)) が使う。
/// 外部依存を増やさないため自前実装する ([ADR 0006](docs/decisions/0006-only-swiftterm-dependency.md))。
///
/// サポート記法: `*` / `*/n` / `a` / `a-b` / `a-b/n` / `a/n` と、それらを `,` で連結したリスト。
/// 非対応: 月名・曜日名 (JAN/MON 等)・`@daily` 等のマクロ・秒フィールド・`L`/`W`/`#` 拡張。
/// 日 (dom) と曜日 (dow) が両方制限されているときは OR で判定する (Vixie cron 互換)。
/// 仕様: docs/specs/widgets/scheduler.md#cron-式の構文
struct CronExpression: Equatable {
    /// 分 (0-59)
    let minutes: Set<Int>
    /// 時 (0-23)
    let hours: Set<Int>
    /// 日 (1-31)
    let daysOfMonth: Set<Int>
    /// 月 (1-12)
    let months: Set<Int>
    /// 曜日 (0=日〜6=土)
    let weekdays: Set<Int>
    /// 日フィールドが `*` 以外 (制限あり) か
    let domRestricted: Bool
    /// 曜日フィールドが `*` 以外 (制限あり) か
    let dowRestricted: Bool

    /// cron 式文字列をパースする。フィールド数不一致・範囲外・不正トークンは nil。
    init?(_ raw: String) {
        let fields = raw.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard fields.count == 5 else { return nil }

        guard let min = Self.parseField(fields[0], min: 0, max: 59),
              let hr = Self.parseField(fields[1], min: 0, max: 23),
              let dom = Self.parseField(fields[2], min: 1, max: 31),
              let mon = Self.parseField(fields[3], min: 1, max: 12),
              let dow = Self.parseField(fields[4], min: 0, max: 7) else {
            return nil
        }

        minutes = min
        hours = hr
        daysOfMonth = dom
        months = mon
        // 曜日は 7 (日) を 0 に正規化する。
        weekdays = Set(dow.map { $0 == 7 ? 0 : $0 })
        domRestricted = fields[2] != "*"
        dowRestricted = fields[4] != "*"
    }

    /// 指定日時 (分粒度) が cron 式に一致するか。秒は無視する。
    func matches(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.month, .day, .hour, .minute, .weekday], from: date)
        guard let month = c.month, let day = c.day, let hour = c.hour,
              let minute = c.minute, let weekday = c.weekday else {
            return false
        }
        let dow = weekday - 1 // Calendar: 1=日 → 0=日
        return minutes.contains(minute)
            && hours.contains(hour)
            && months.contains(month)
            && dayMatches(day: day, dow: dow)
    }

    /// `from` より後で最初に式へ一致する Date (分粒度) を返す。見つからなければ nil。
    /// 月・日・時・分の不一致をフィールド単位でスキップして探索する。
    func nextDate(after from: Date, calendar: Calendar = .current) -> Date? {
        // from を分粒度に丸めて 1 分進めた時点から探す。
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: from)
        comps.second = 0
        guard let truncated = calendar.date(from: comps),
              var probe = calendar.date(byAdding: .minute, value: 1, to: truncated) else {
            return nil
        }

        // 不可能な式 (例: 2月30日) に備えた上限。フィールドスキップ前提で十分大きい値。
        let maxIterations = 600_000
        for _ in 0..<maxIterations {
            let c = calendar.dateComponents([.month, .day, .hour, .minute, .weekday], from: probe)
            guard let month = c.month, let day = c.day, let hour = c.hour,
                  let minute = c.minute, let weekday = c.weekday else {
                return nil
            }
            let dow = weekday - 1

            if !months.contains(month) {
                guard let next = Self.startOfNextMonth(probe, calendar) else { return nil }
                probe = next
                continue
            }
            if !dayMatches(day: day, dow: dow) {
                guard let next = Self.startOfNextDay(probe, calendar) else { return nil }
                probe = next
                continue
            }
            if !hours.contains(hour) {
                guard let next = Self.startOfNextHour(probe, calendar) else { return nil }
                probe = next
                continue
            }
            if !minutes.contains(minute) {
                guard let next = calendar.date(byAdding: .minute, value: 1, to: probe) else { return nil }
                probe = next
                continue
            }
            return probe
        }
        return nil
    }

    // MARK: - private

    /// 日 (dom) / 曜日 (dow) の一致判定。両方制限あり → OR、片方のみ → その片方、両方 `*` → 常に真。
    private func dayMatches(day: Int, dow: Int) -> Bool {
        switch (domRestricted, dowRestricted) {
        case (true, true): return daysOfMonth.contains(day) || weekdays.contains(dow)
        case (true, false): return daysOfMonth.contains(day)
        case (false, true): return weekdays.contains(dow)
        case (false, false): return true
        }
    }

    /// 1 フィールドを許容値の Set に展開する。範囲外・不正トークンは nil。
    private static func parseField(_ field: String, min: Int, max: Int) -> Set<Int>? {
        guard !field.isEmpty else { return nil }
        var result = Set<Int>()
        for term in field.split(separator: ",", omittingEmptySubsequences: false) {
            guard let values = parseTerm(String(term), min: min, max: max) else { return nil }
            result.formUnion(values)
        }
        return result.isEmpty ? nil : result
    }

    /// `*` / `*/n` / `a` / `a-b` / `a-b/n` / `a/n` の 1 項を展開する。
    private static func parseTerm(_ term: String, min: Int, max: Int) -> Set<Int>? {
        guard !term.isEmpty else { return nil }

        // ステップ (`base/step`) の分離
        let stepParts = term.split(separator: "/", omittingEmptySubsequences: false)
        guard stepParts.count <= 2 else { return nil }
        var step = 1
        if stepParts.count == 2 {
            guard let s = Int(stepParts[1]), s >= 1 else { return nil }
            step = s
        }
        let base = String(stepParts[0])

        // base の範囲を決める
        let lower: Int
        let upper: Int
        if base == "*" {
            lower = min
            upper = max
        } else if base.contains("-") {
            let rangeParts = base.split(separator: "-", omittingEmptySubsequences: false)
            guard rangeParts.count == 2,
                  let a = Int(rangeParts[0]), let b = Int(rangeParts[1]),
                  a <= b else { return nil }
            lower = a
            upper = b
        } else {
            guard let v = Int(base) else { return nil }
            // `a/n` は a から max まで n 刻み。ステップ無しの単一値は a のみ。
            lower = v
            upper = stepParts.count == 2 ? max : v
        }

        guard lower >= min, upper <= max else { return nil }

        var values = Set<Int>()
        var v = lower
        while v <= upper {
            values.insert(v)
            v += step
        }
        return values
    }

    private static func startOfNextDay(_ date: Date, _ calendar: Calendar) -> Date? {
        let sod = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: sod)
    }

    private static func startOfNextHour(_ date: Date, _ calendar: Calendar) -> Date? {
        let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        guard let base = calendar.date(from: comps) else { return nil }
        return calendar.date(byAdding: .hour, value: 1, to: base)
    }

    private static func startOfNextMonth(_ date: Date, _ calendar: Calendar) -> Date? {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let base = calendar.date(from: comps) else { return nil }
        return calendar.date(byAdding: .month, value: 1, to: base)
    }
}
