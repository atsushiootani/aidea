//
//  CompanionRosterWriterTests.swift
//  AideaTests
//

import XCTest
@testable import Aidea

/// CompanionRosterWriter.render の単体テスト
/// 仕様: docs/specs/backchannels/companion-roster.md
final class CompanionRosterWriterTests: XCTestCase {

    /// テスト用に `Companion N` 形式のデフォルト 9 体を生成する
    private func defaultCompanions() -> [CompanionConfig] {
        (0..<9).map {
            CompanionConfig(
                index: $0,
                name: "Companion \($0 + 1)",
                icon: "Companions/companion-\($0 + 1)",
                sessionID: nil
            )
        }
    }

    /// マーカー両方が存在する場合、内側 9 行が新 roster で上書きされる
    func testReplaceBetweenMarkers() {
        let existing = """
        # Aidea Backchannel 指示

        本文の前半部分。

        <!-- aidea:companions:start -->
        - 0: Old Name
        - 1: Stale
        <!-- aidea:companions:end -->

        後半の本文。
        """
        let companions = defaultCompanions()
        let result = CompanionRosterWriter.render(existing: existing, companions: companions)

        XCTAssertTrue(result.contains("- 0: Companion 1"))
        XCTAssertTrue(result.contains("- 8: Companion 9"))
        XCTAssertFalse(result.contains("Old Name"))
        XCTAssertFalse(result.contains("Stale"))
        XCTAssertTrue(result.contains("本文の前半部分。"))
        XCTAssertTrue(result.contains("後半の本文。"))
    }

    /// マーカー外の本文 (見出し・段落) は一切変更されない
    func testMarkerOutsideContentPreserved() {
        let existing = """
        # ユーザの自由編集セクション

        ハンドオフは便利だよ。

        <!-- aidea:companions:start -->
        - 0: foo
        <!-- aidea:companions:end -->

        ## 末尾の見出し

        ここも保護される。
        """
        let result = CompanionRosterWriter.render(existing: existing, companions: defaultCompanions())

        XCTAssertTrue(result.contains("# ユーザの自由編集セクション"))
        XCTAssertTrue(result.contains("ハンドオフは便利だよ。"))
        XCTAssertTrue(result.contains("## 末尾の見出し"))
        XCTAssertTrue(result.contains("ここも保護される。"))
    }

    /// マーカーが両方とも無い場合、末尾に推奨セクションが追記される (本文は破壊しない)
    func testAppendsSectionWhenMarkersMissing() {
        let existing = """
        # Aidea Backchannel 指示

        既存の本文だけがあるパターン。
        """
        let result = CompanionRosterWriter.render(existing: existing, companions: defaultCompanions())

        XCTAssertTrue(result.contains("# Aidea Backchannel 指示"))
        XCTAssertTrue(result.contains("既存の本文だけがあるパターン。"))
        XCTAssertTrue(result.contains("## ワークスペースのコンパニオン一覧"))
        XCTAssertTrue(result.contains(CompanionRosterWriter.markerStart))
        XCTAssertTrue(result.contains(CompanionRosterWriter.markerEnd))
        XCTAssertTrue(result.contains("- 0: Companion 1"))
        XCTAssertTrue(result.contains("- 8: Companion 9"))
    }

    /// マーカーが片方しかない (壊れた状態) の場合は末尾追記モードで処理される (壊れたマーカーは触らない)
    func testAppendsSectionWhenStartMarkerOnly() {
        let existing = """
        # 既存

        <!-- aidea:companions:start -->
        - 0: orphan
        """
        let result = CompanionRosterWriter.render(existing: existing, companions: defaultCompanions())

        // 既存の壊れた start マーカーは残る
        XCTAssertTrue(result.contains("- 0: orphan"))
        // 新しい正規セクションが末尾に追記される
        XCTAssertTrue(result.contains("## ワークスペースのコンパニオン一覧"))
        XCTAssertTrue(result.contains(CompanionRosterWriter.markerEnd))
    }

    /// roster が既存と完全に一致する場合、結果も完全に同一文字列を返す (mtime 更新を避ける呼び出し側のスキップ判定で利用)
    func testIdempotentWhenRosterUnchanged() {
        let companions = defaultCompanions()
        let firstRender = CompanionRosterWriter.render(
            existing: "# Header\n",
            companions: companions
        )
        let secondRender = CompanionRosterWriter.render(existing: firstRender, companions: companions)
        XCTAssertEqual(firstRender, secondRender)
    }

    /// CRLF 改行を含むファイルは結果も CRLF で出力される
    func testCRLFLineEndingPreserved() {
        let existing = "# Header\r\n\r\n<!-- aidea:companions:start -->\r\n- 0: old\r\n<!-- aidea:companions:end -->\r\n"
        let result = CompanionRosterWriter.render(existing: existing, companions: defaultCompanions())

        XCTAssertTrue(result.contains("\r\n- 0: Companion 1\r\n"))
        XCTAssertFalse(result.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
    }

    /// companions が index 昇順でなくても、出力は index 昇順 (0..8) で並ぶ
    func testCompanionsSortedByIndex() {
        let shuffled: [CompanionConfig] = [
            CompanionConfig(index: 5, name: "Five", icon: "x", sessionID: nil),
            CompanionConfig(index: 0, name: "Zero", icon: "x", sessionID: nil),
            CompanionConfig(index: 8, name: "Eight", icon: "x", sessionID: nil)
        ]
        let existing = "<!-- aidea:companions:start -->\n<!-- aidea:companions:end -->\n"
        let result = CompanionRosterWriter.render(existing: existing, companions: shuffled)

        guard let zeroRange = result.range(of: "- 0: Zero"),
              let fiveRange = result.range(of: "- 5: Five"),
              let eightRange = result.range(of: "- 8: Eight") else {
            return XCTFail("expected entries not found in render result")
        }
        XCTAssertLessThan(zeroRange.lowerBound, fiveRange.lowerBound)
        XCTAssertLessThan(fiveRange.lowerBound, eightRange.lowerBound)
    }
}
