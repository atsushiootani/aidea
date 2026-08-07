//
//  SnippetConfigTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// `SnippetConfig` の Codable 後方互換を検証する。
/// 仕様: docs/specs/widgets/snippets.md (「旧フォーマットの enabled キーは読み込み時に無視される
/// (未知キーを読み飛ばす後方互換)」、issue #285)
struct SnippetConfigTests {

    private func decodeSnippet(_ json: String) throws -> SnippetConfig.Snippet {
        try JSONDecoder().decode(SnippetConfig.Snippet.self, from: Data(json.utf8))
    }

    @Test("旧フォーマット (enabled キーあり) が読めて、他フィールドが失われない")
    func decodesOldFormatWithEnabledKey() throws {
        let json = """
        {"id":"s1","name":"Snip","command":"echo hi","enabled":true}
        """
        let snippet = try decodeSnippet(json)

        #expect(snippet.id == "s1")
        #expect(snippet.name == "Snip")
        #expect(snippet.command == "echo hi")
    }

    @Test("destination 省略時は nil (既定 = アクティブ端末) になる")
    func destinationDefaultsToNilWhenOmitted() throws {
        let json = """
        {"id":"s1","name":"Snip","command":"echo hi"}
        """
        let snippet = try decodeSnippet(json)

        #expect(snippet.destination == nil)
    }

    @Test("destination の type: new / type: tab + title がそれぞれ正しく読める")
    func decodesDestinationVariants() throws {
        let new = try JSONDecoder().decode(SnippetConfig.Destination.self, from: Data(#"{"type":"new"}"#.utf8))
        #expect(new == .new)

        let tab = try JSONDecoder().decode(
            SnippetConfig.Destination.self,
            from: Data(#"{"type":"tab","title":"logs"}"#.utf8)
        )
        #expect(tab == .tab(title: "logs"))
    }

    @Test("destination の未知の type はデコードエラーになる")
    func unknownDestinationTypeThrows() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                SnippetConfig.Destination.self,
                from: Data(#"{"type":"unknown"}"#.utf8)
            )
        }
    }

    @Test("Snippet は encode → decode の往復で同値になる")
    func snippetRoundTrips() throws {
        let original = SnippetConfig.Snippet(
            id: "s1", name: "Snip", command: "echo hi", destination: .tab(title: "logs")
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SnippetConfig.Snippet.self, from: data)

        #expect(decoded == original)
    }
}
