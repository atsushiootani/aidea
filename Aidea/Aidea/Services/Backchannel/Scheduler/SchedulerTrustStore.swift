//
//  SchedulerTrustStore.swift
//  Aidea
//

import CryptoKit
import Foundation

/// プロジェクトの `.aidea/config/scheduler.json` をユーザが承認した記録を持つ (issue #293)。
/// scheduler.json はリポジトリに含めて配布できるため信頼できない入力として扱い、
/// 「プロジェクトパス + 設定ファイル内容のハッシュ」の組が承認済みのときだけ自動実行を許す。
/// 記録はリポジトリの外 (`~/Library/Application Support/Aidea/scheduler-trust.json`) に置き、
/// プロジェクト側から承認を偽装できないようにする。内容が 1 バイトでも変われば未承認に戻る。
/// docs/specs/widgets/scheduler.md 参照。
struct SchedulerTrustStore {
    /// 承認記録ファイルの URL。テストでは一時ディレクトリを渡す。
    let fileURL: URL

    init(fileURL: URL = SchedulerTrustStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    /// 既定の承認記録ファイル (`~/Library/Application Support/Aidea/scheduler-trust.json`)。
    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        return base
            .appending(path: "Aidea", directoryHint: .isDirectory)
            .appending(path: "scheduler-trust.json")
    }

    /// 承認記録ファイルの形。プロジェクトパス → 承認した設定内容の SHA-256 (hex)。
    private struct Records: Codable {
        var projects: [String: String] = [:]
    }

    /// 指定プロジェクトの設定内容 `configData` が承認済みか。
    func isTrusted(projectRoot: URL, configData: Data) -> Bool {
        load().projects[Self.key(for: projectRoot)] == Self.contentHash(configData)
    }

    /// 指定プロジェクトの設定内容 `configData` を承認済みとして記録する (同プロジェクトの旧記録は置き換え)。
    func trust(projectRoot: URL, configData: Data) {
        var records = load()
        records.projects[Self.key(for: projectRoot)] = Self.contentHash(configData)
        save(records)
    }

    /// 記録のキー: シンボリックリンクを解決・正規化した絶対パス
    /// (同じプロジェクトを別名パスで開いても同じ記録に当たるように)。
    static func key(for projectRoot: URL) -> String {
        projectRoot.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// 設定内容の SHA-256 を小文字 hex で返す。
    static func contentHash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - private

    private func load() -> Records {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode(Records.self, from: data) else {
            return Records()
        }
        return records
    }

    private func save(_ records: Records) {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[Aidea] scheduler trust save failed: \(error.localizedDescription)")
        }
    }
}
