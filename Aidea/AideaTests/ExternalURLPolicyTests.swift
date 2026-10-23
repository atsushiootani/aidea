//
//  ExternalURLPolicyTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// 外部 URL の scheme 許可リスト (issue #294) を検証する。
/// 仕様: docs/specs/tools/web.md#外部-scheme-のナビゲーション / docs/specs/tools/terminal.md#url-クリック
struct ExternalURLPolicyTests {

    private func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    // MARK: - isWebURL

    @Test func isWebURLAcceptsHTTPAndHTTPS() throws {
        #expect(ExternalURLPolicy.isWebURL(try url("https://example.com/path")))
        #expect(ExternalURLPolicy.isWebURL(try url("http://localhost:3000")))
        #expect(ExternalURLPolicy.isWebURL(try url("HTTPS://EXAMPLE.COM")))
    }

    @Test func isWebURLRejectsOtherSchemesAndSwitchLikeStrings() throws {
        #expect(!ExternalURLPolicy.isWebURL(try url("--load-extension=/tmp/ext")))
        #expect(!ExternalURLPolicy.isWebURL(try url("file:///Applications/Calculator.app")))
        #expect(!ExternalURLPolicy.isWebURL(try url("vscode://vscode.git/clone?url=x")))
        #expect(!ExternalURLPolicy.isWebURL(try url("javascript:alert(1)")))
        #expect(!ExternalURLPolicy.isWebURL(try url("https:")))
    }

    // MARK: - webNavigation

    @Test func webNavigationAllowsWebKitSchemes() throws {
        for s in ["https://example.com", "http://example.com", "about:blank", "blob:https://example.com/uuid",
                  "data:text/plain,hi"] {
            #expect(ExternalURLPolicy.webNavigation(try url(s), userInitiated: false) == .allow)
        }
    }

    @Test func webNavigationRejectsExternalSchemesWithoutUserGesture() throws {
        for s in ["vscode://x", "zoommtg://x", "smb://attacker.example/share", "aidea://open-workspace?path=/"] {
            #expect(ExternalURLPolicy.webNavigation(try url(s), userInitiated: false) == .reject)
        }
    }

    @Test func webNavigationConfirmsExternalSchemesOnUserClick() throws {
        #expect(ExternalURLPolicy.webNavigation(try url("mailto:a@example.com"), userInitiated: true) == .confirmExternal)
        #expect(ExternalURLPolicy.webNavigation(try url("vscode://x"), userInitiated: true) == .confirmExternal)
    }

    @Test func webNavigationNeverHandsFileURLsOut() throws {
        #expect(ExternalURLPolicy.webNavigation(try url("file:///Applications/Calculator.app"), userInitiated: true) == .reject)
    }

    // MARK: - terminalLink

    @Test func terminalLinkRoutesHTTPToWeb() throws {
        #expect(ExternalURLPolicy.terminalLink(try url("https://github.com/org/repo")) == .openWeb)
    }

    @Test func terminalLinkConfirmsOtherSchemes() throws {
        #expect(ExternalURLPolicy.terminalLink(try url("ssh://host")) == .confirmExternal)
        #expect(ExternalURLPolicy.terminalLink(try url("smb://attacker.example/share")) == .confirmExternal)
        #expect(ExternalURLPolicy.terminalLink(try url("aidea://open-workspace?path=/tmp")) == .confirmExternal)
    }

    @Test func terminalLinkPreviewsRegularFilesOnly() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aidea-urlpolicy-\(UUID().uuidString)")
        let bundle = base.appendingPathComponent("Setup.app/Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("note.md")
        try Data("x".utf8).write(to: file)
        let link = base.appendingPathComponent("link.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: base.appendingPathComponent("Setup.app"))

        if case .openPreview = ExternalURLPolicy.terminalLink(file) {} else {
            Issue.record("通常ファイルは Preview に回るべき")
        }
        #expect(ExternalURLPolicy.terminalLink(base.appendingPathComponent("Setup.app")) == .reject)
        #expect(ExternalURLPolicy.terminalLink(link) == .reject)
        #expect(ExternalURLPolicy.terminalLink(base.appendingPathComponent("missing.command")) == .reject)
        #expect(ExternalURLPolicy.terminalLink(try url("file://server.example/share/x.txt")) == .reject)
    }
}
