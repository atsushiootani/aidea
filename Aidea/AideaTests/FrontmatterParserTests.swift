//
//  FrontmatterParserTests.swift
//  AideaTests
//

import XCTest
@testable import Aidea

/// FrontmatterParser の単体テスト
final class FrontmatterParserTests: XCTestCase {

    /// 正常系: name と description を持つ frontmatter
    func testNormalFrontmatter() {
        let source = """
        ---
        name: my-skill
        description: A test skill
        ---
        # Body
        Hello
        """
        let (front, body) = FrontmatterParser.parse(source)
        XCTAssertEqual(front["name"], "my-skill")
        XCTAssertEqual(front["description"], "A test skill")
        XCTAssertTrue(body.contains("# Body"))
        XCTAssertTrue(body.contains("Hello"))
    }

    /// 空の frontmatter (--- だけ並ぶ)
    func testEmptyFrontmatter() {
        let source = """
        ---
        ---
        body only
        """
        let (front, body) = FrontmatterParser.parse(source)
        XCTAssertTrue(front.isEmpty)
        XCTAssertEqual(body, "body only")
    }

    /// frontmatter なし (先頭が --- でない)
    func testNoFrontmatter() {
        let source = "no frontmatter here\nline 2"
        let (front, body) = FrontmatterParser.parse(source)
        XCTAssertTrue(front.isEmpty)
        XCTAssertEqual(body, source)
    }

    /// 閉じの --- が無い不正なケース
    func testUnclosedFrontmatter() {
        let source = """
        ---
        name: broken
        body without closing
        """
        let (front, body) = FrontmatterParser.parse(source)
        XCTAssertTrue(front.isEmpty)
        XCTAssertEqual(body, source)
    }
}
