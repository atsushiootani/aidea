//
//  ShellCommandSanitizerTests.swift
//  AideaTests
//

import XCTest
@testable import Aidea

/// ShellCommandSanitizer の単体テスト
final class ShellCommandSanitizerTests: XCTestCase {

    /// 制御文字を含まないコマンドはそのまま
    func testPlainCommandUnchanged() {
        let source = "echo \"こんにちは\" | grep -n 'x'"
        XCTAssertEqual(ShellCommandSanitizer.sanitize(source), source)
    }

    /// 改行とタブは残す
    func testKeepsNewlineAndTab() {
        let source = "ls -la\n\techo ok\n"
        XCTAssertEqual(ShellCommandSanitizer.sanitize(source), source)
    }

    /// ESC / BEL / BS / NUL などの C0 制御文字を除去する
    func testStripsC0Controls() {
        let source = "echo hi\u{1B}[2K\u{07}\u{08}\u{00}\u{03}\u{15}\u{1F}"
        XCTAssertEqual(ShellCommandSanitizer.sanitize(source), "echo hi[2K")
    }

    /// CR は除去し、CRLF は LF になる
    func testStripsCarriageReturn() {
        XCTAssertEqual(ShellCommandSanitizer.sanitize("a\r\nb\rc"), "a\nbc")
    }

    /// DEL と C1 制御文字 (CSI U+009B など) を除去する
    func testStripsDelAndC1Controls() {
        let source = "x\u{7F}y\u{80}\u{9B}31mz\u{9F}"
        XCTAssertEqual(ShellCommandSanitizer.sanitize(source), "xy31mz")
    }

    /// C1 範囲外の非 ASCII 文字 (U+00A0 以降) は残す
    func testKeepsNonControlUnicode() {
        let source = "\u{A0}é日本語🎉"
        XCTAssertEqual(ShellCommandSanitizer.sanitize(source), source)
    }

    /// 境界値: U+001F/U+007F/U+009F は除去、U+0020/U+007E/U+00A0 は残す
    func testBoundaries() {
        XCTAssertTrue(ShellCommandSanitizer.isStripped("\u{1F}"))
        XCTAssertTrue(ShellCommandSanitizer.isStripped("\u{7F}"))
        XCTAssertTrue(ShellCommandSanitizer.isStripped("\u{9F}"))
        XCTAssertFalse(ShellCommandSanitizer.isStripped("\u{20}"))
        XCTAssertFalse(ShellCommandSanitizer.isStripped("\u{7E}"))
        XCTAssertFalse(ShellCommandSanitizer.isStripped("\u{A0}"))
    }
}
