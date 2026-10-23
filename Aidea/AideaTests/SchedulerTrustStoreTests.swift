//
//  SchedulerTrustStoreTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// scheduler.json の承認記録 (プロジェクトパス + 内容ハッシュ) を検証する (issue #293)。
/// 仕様: docs/specs/widgets/scheduler.md
struct SchedulerTrustStoreTests {

    /// テストごとに独立した一時ディレクトリ
    private let tempDir: URL = FileManager.default.temporaryDirectory
        .appending(path: "SchedulerTrustStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    private var store: SchedulerTrustStore {
        SchedulerTrustStore(fileURL: tempDir.appending(path: "trust.json"))
    }

    private let projectA = URL(fileURLWithPath: "/tmp/project-a", isDirectory: true)
    private let projectB = URL(fileURLWithPath: "/tmp/project-b", isDirectory: true)
    private let config1 = Data(#"{"jobs":[{"id":"a","prompt":"echo 1"}]}"#.utf8)
    private let config2 = Data(#"{"jobs":[{"id":"a","prompt":"echo 2"}]}"#.utf8)

    @Test("記録が無ければ未承認")
    func untrustedByDefault() {
        #expect(!store.isTrusted(projectRoot: projectA, configData: config1))
    }

    @Test("承認した内容は承認済みになり、記録はファイルに永続化される")
    func trustPersists() {
        store.trust(projectRoot: projectA, configData: config1)
        let reopened = SchedulerTrustStore(fileURL: tempDir.appending(path: "trust.json"))
        #expect(reopened.isTrusted(projectRoot: projectA, configData: config1))
    }

    @Test("内容が変われば未承認に戻る")
    func changedContentIsUntrusted() {
        store.trust(projectRoot: projectA, configData: config1)
        #expect(!store.isTrusted(projectRoot: projectA, configData: config2))
    }

    @Test("承認は別プロジェクトに波及しない")
    func trustIsPerProject() {
        store.trust(projectRoot: projectA, configData: config1)
        #expect(!store.isTrusted(projectRoot: projectB, configData: config1))
    }

    @Test("再承認で同プロジェクトの記録は新しい内容に置き換わる")
    func retrustReplaces() {
        store.trust(projectRoot: projectA, configData: config1)
        store.trust(projectRoot: projectA, configData: config2)
        #expect(store.isTrusted(projectRoot: projectA, configData: config2))
        #expect(!store.isTrusted(projectRoot: projectA, configData: config1))
    }

    @Test("同じプロジェクトを正規化前のパスで開いても同じ記録に当たる")
    func keyIsNormalized() {
        store.trust(projectRoot: projectA, configData: config1)
        let alias = URL(fileURLWithPath: "/tmp/project-a/sub/..", isDirectory: true)
        #expect(store.isTrusted(projectRoot: alias, configData: config1))
    }

    @Test("内容ハッシュは SHA-256 の hex")
    func contentHashIsSHA256() {
        #expect(SchedulerTrustStore.contentHash(Data("abc".utf8))
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
