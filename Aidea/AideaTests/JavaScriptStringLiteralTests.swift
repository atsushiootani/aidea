//
//  JavaScriptStringLiteralTests.swift
//  AideaTests
//

import XCTest
@testable import Aidea

/// JavaScriptStringLiteral の単体テスト
final class JavaScriptStringLiteralTests: XCTestCase {

    /// リテラルを JSON として読み戻した値 (= JS が評価する値)
    private func decode(_ literal: String) throws -> String {
        let data = Data(literal.utf8)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? String)
    }

    /// script 終了タグを含んでも `<` が残らず、元の文字列に戻る
    func testScriptEndTagIsNeutralized() throws {
        let input = "graph TD\nA-->B</script><script>alert(1)</script>"
        let literal = JavaScriptStringLiteral.make(input)
        XCTAssertFalse(literal.contains("<"))
        XCTAssertFalse(literal.contains(">"))
        XCTAssertFalse(literal.lowercased().contains("</script"))
        XCTAssertEqual(try decode(literal), input)
    }

    /// HTML コメント開始や & もエスケープされる
    func testHTMLSignificantCharacters() throws {
        let input = "<!-- a & b -->"
        let literal = JavaScriptStringLiteral.make(input)
        XCTAssertFalse(literal.contains("<"))
        XCTAssertFalse(literal.contains("&"))
        XCTAssertEqual(try decode(literal), input)
    }

    /// クォート・バックスラッシュ・テンプレート記法・改行類が値を壊さない
    func testQuotesBackslashAndLineSeparators() throws {
        let input = "a\"b'c\\d`e${f}\ng\u{2028}h\u{2029}i"
        let literal = JavaScriptStringLiteral.make(input)
        XCTAssertTrue(literal.hasPrefix("\""))
        XCTAssertTrue(literal.hasSuffix("\""))
        XCTAssertFalse(literal.contains("\n"))
        XCTAssertFalse(literal.contains("\u{2028}"))
        XCTAssertFalse(literal.contains("\u{2029}"))
        XCTAssertEqual(try decode(literal), input)
    }

    /// 空文字列
    func testEmpty() throws {
        XCTAssertEqual(JavaScriptStringLiteral.make(""), "\"\"")
    }
}
