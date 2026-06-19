//
//  CronExpressionTests.swift
//  AideaTests
//

import XCTest
@testable import Aidea

/// 自前 cron パーサ `CronExpression` のパース・一致判定・次回発火計算を検証する。
/// 仕様: docs/specs/widgets/scheduler.md#cron-式の構文 / ADR 0034
final class CronExpressionTests: XCTestCase {

    // MARK: - helpers

    /// 決定的な計算のため Asia/Tokyo 固定の Gregorian カレンダーを使う。
    private func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = d; comps.hour = h; comps.minute = mi; comps.second = 0
        return cal().date(from: comps)!
    }

    // MARK: - パース (正常)

    func testParseEveryFiveMinutes() throws {
        let cron = try XCTUnwrap(CronExpression("*/5 * * * *"))
        XCTAssertEqual(cron.minutes, Set(stride(from: 0, through: 55, by: 5)))
        XCTAssertEqual(cron.hours, Set(0...23))
        XCTAssertEqual(cron.months, Set(1...12))
        XCTAssertFalse(cron.domRestricted)
        XCTAssertFalse(cron.dowRestricted)
    }

    func testParseRangeAndList() throws {
        let cron = try XCTUnwrap(CronExpression("0,30 9-18 * * 1-5"))
        XCTAssertEqual(cron.minutes, [0, 30])
        XCTAssertEqual(cron.hours, Set(9...18))
        XCTAssertEqual(cron.weekdays, [1, 2, 3, 4, 5])
        XCTAssertTrue(cron.dowRestricted)
        XCTAssertFalse(cron.domRestricted)
    }

    func testParseRangeWithStep() throws {
        let cron = try XCTUnwrap(CronExpression("0-30/10 * * * *"))
        XCTAssertEqual(cron.minutes, [0, 10, 20, 30])
    }

    func testParseSundayAsSevenNormalizesToZero() throws {
        let cron = try XCTUnwrap(CronExpression("0 0 * * 7"))
        XCTAssertTrue(cron.weekdays.contains(0))
        XCTAssertTrue(cron.dowRestricted)
    }

    // MARK: - パース (異常)

    func testParseInvalid() {
        XCTAssertNil(CronExpression(""))
        XCTAssertNil(CronExpression("* * * *"))          // 4 フィールド
        XCTAssertNil(CronExpression("* * * * * *"))      // 6 フィールド (秒非対応)
        XCTAssertNil(CronExpression("60 * * * *"))       // 分が範囲外
        XCTAssertNil(CronExpression("* 24 * * *"))       // 時が範囲外
        XCTAssertNil(CronExpression("* * 0 * *"))        // 日は 1 始まり
        XCTAssertNil(CronExpression("* * * 13 *"))       // 月が範囲外
        XCTAssertNil(CronExpression("* * * * 8"))        // 曜日が範囲外
        XCTAssertNil(CronExpression("*/0 * * * *"))      // ステップ 0
        XCTAssertNil(CronExpression("abc * * * *"))      // 不正トークン
        XCTAssertNil(CronExpression("1-2-3 * * * *"))    // 範囲の二重ハイフン
        XCTAssertNil(CronExpression("5-2 * * * *"))      // 逆順範囲
    }

    // MARK: - matches

    func testMatches() throws {
        let cron = try XCTUnwrap(CronExpression("*/10 9-18 * * 1-5"))
        let c = cal()
        XCTAssertTrue(cron.matches(date(2026, 6, 19, 12, 10), calendar: c)) // 金 12:10
        XCTAssertFalse(cron.matches(date(2026, 6, 19, 12, 15), calendar: c)) // 分が不一致
        XCTAssertFalse(cron.matches(date(2026, 6, 19, 8, 10), calendar: c))  // 時間帯外
        XCTAssertFalse(cron.matches(date(2026, 6, 20, 12, 10), calendar: c)) // 土曜
    }

    // MARK: - nextDate

    func testNextEveryFiveMinutes() throws {
        let cron = try XCTUnwrap(CronExpression("*/5 * * * *"))
        XCTAssertEqual(cron.nextDate(after: date(2026, 6, 19, 12, 2), calendar: cal()),
                       date(2026, 6, 19, 12, 5))
    }

    func testNextEverySixHours() throws {
        let cron = try XCTUnwrap(CronExpression("0 */6 * * *"))
        XCTAssertEqual(cron.nextDate(after: date(2026, 6, 19, 7, 0), calendar: cal()),
                       date(2026, 6, 19, 12, 0))
        XCTAssertEqual(cron.nextDate(after: date(2026, 6, 19, 18, 30), calendar: cal()),
                       date(2026, 6, 20, 0, 0))
    }

    func testNextDailyAtNine() throws {
        let cron = try XCTUnwrap(CronExpression("0 9 * * *"))
        XCTAssertEqual(cron.nextDate(after: date(2026, 6, 19, 10, 0), calendar: cal()),
                       date(2026, 6, 20, 9, 0))
    }

    func testNextWeekdayBusinessHours() throws {
        let cron = try XCTUnwrap(CronExpression("*/10 9-18 * * 1-5"))
        // 金 12:03 → 同日 12:10
        XCTAssertEqual(cron.nextDate(after: date(2026, 6, 19, 12, 3), calendar: cal()),
                       date(2026, 6, 19, 12, 10))
        // 金 18:55 → 翌週月 (6/22) 09:00 (土日スキップ)
        XCTAssertEqual(cron.nextDate(after: date(2026, 6, 19, 18, 55), calendar: cal()),
                       date(2026, 6, 22, 9, 0))
    }

    func testNextDomOrDow() throws {
        // 日 (1日) または 曜日 (月) のどちらか一致で発火 (OR)
        let cron = try XCTUnwrap(CronExpression("0 0 1 * 1"))
        // 金 6/19 00:00 起点 → 次の月曜 6/22 (1日より先に到来)
        XCTAssertEqual(cron.nextDate(after: date(2026, 6, 19, 0, 0), calendar: cal()),
                       date(2026, 6, 22, 0, 0))
    }

    func testNextDomOnly() throws {
        let cron = try XCTUnwrap(CronExpression("0 0 1 * *"))
        XCTAssertEqual(cron.nextDate(after: date(2026, 6, 19, 0, 0), calendar: cal()),
                       date(2026, 7, 1, 0, 0))
    }
}
