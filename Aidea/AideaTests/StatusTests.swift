//
//  StatusTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// status.json の読み取りと表示条件を検証する。
/// 仕様: docs/specs/backchannels/status.md
struct StatusWatcherReadTests {

    private func withStatusFile(_ contents: String?, _ body: (URL) throws -> Void) throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aidea-status-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("status.json")
        if let contents {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        try body(url)
    }

    @Test("status の文字列をそのまま読む")
    func readsStatusString() throws {
        try withStatusFile(#"{"status": "テストを実装しています"}"#) { url in
            #expect(StatusWatcher.readStatus(at: url) == "テストを実装しています")
        }
    }

    @Test("空文字列は空のまま返す (非表示の合図)")
    func emptyStatusStaysEmpty() throws {
        try withStatusFile(#"{"status": ""}"#) { url in
            #expect(StatusWatcher.readStatus(at: url).isEmpty)
        }
    }

    @Test("前後の空白・改行はトリムする")
    func trimsWhitespace() throws {
        try withStatusFile("{\"status\": \"  作業中  \\n\"}") { url in
            #expect(StatusWatcher.readStatus(at: url) == "作業中")
        }
    }

    @Test("空白だけの status は空扱い (非表示)")
    func whitespaceOnlyBecomesEmpty() throws {
        try withStatusFile(#"{"status": "   "}"#) { url in
            #expect(StatusWatcher.readStatus(at: url).isEmpty)
        }
    }

    @Test("ファイルが存在しなければ空 (非表示)")
    func missingFileIsEmpty() throws {
        try withStatusFile(nil) { url in
            #expect(StatusWatcher.readStatus(at: url).isEmpty)
        }
    }

    @Test("JSON が壊れていても落ちずに空を返す")
    func brokenJSONIsEmpty() throws {
        try withStatusFile("{これはJSONではない") { url in
            #expect(StatusWatcher.readStatus(at: url).isEmpty)
        }
    }

    @Test("status キーが無ければ空 (非表示)")
    func missingKeyIsEmpty() throws {
        try withStatusFile(#"{"state": "working"}"#) { url in
            #expect(StatusWatcher.readStatus(at: url).isEmpty)
        }
    }
}

/// hooks が書き込む文言の既定値。
struct StatusLabelsConfigTests {

    @Test("既定値は 作業中 / 要返答")
    func defaults() {
        let config = StatusLabelsConfig()

        #expect(config.working == "作業中")
        #expect(config.waiting == "要返答")
    }

    @Test("JSON から文言を上書きできる")
    func decodesCustomLabels() throws {
        let json = #"{"working": "少女作業中", "waiting": "きて〜！"}"#
        let config = try JSONDecoder().decode(StatusLabelsConfig.self, from: Data(json.utf8))

        #expect(config.working == "少女作業中")
        #expect(config.waiting == "きて〜！")
    }

    @Test("片方だけ指定してももう片方は既定値のまま")
    func partialOverrideKeepsDefault() throws {
        let json = #"{"working": "がんばってる"}"#
        let config = try JSONDecoder().decode(StatusLabelsConfig.self, from: Data(json.utf8))

        #expect(config.working == "がんばってる")
        #expect(config.waiting == "要返答")
    }
}
