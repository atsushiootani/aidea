//
//  SchedulerStore.swift
//  Aidea
//

import Foundation

/// `.aidea/config/scheduler.json` (ユーザ編集の config) と `.aidea/state/scheduler.json`
/// (自動管理の state) の読み書きを担う。JSON は `WorkspaceSnapshotManager` と同じ
/// `.prettyPrinted, .sortedKeys` + `.atomic` write パターンに揃える。
/// config 不在は空 (ジョブ無し)、state 不在は空マップにフォールバックする (個人用アプリのため try? 握りつぶし)。
/// docs/specs/widgets/scheduler.md 参照。
struct SchedulerStore {
    /// プロジェクトルート。`start()` 時に SchedulerState から渡される。
    let projectRoot: URL

    /// config (`.aidea/config/scheduler.json`) の URL
    private var configURL: URL {
        projectRoot
            .appending(path: ".aidea", directoryHint: .isDirectory)
            .appending(path: "config", directoryHint: .isDirectory)
            .appending(path: "scheduler.json")
    }

    /// state (`.aidea/state/scheduler.json`) の URL
    private var stateURL: URL {
        projectRoot
            .appending(path: ".aidea", directoryHint: .isDirectory)
            .appending(path: "state", directoryHint: .isDirectory)
            .appending(path: "scheduler.json")
    }

    // MARK: - Config (read only)

    /// config を読み込む。ファイル不在 / デコード失敗時は空 config (ジョブ無し) を返す。
    func loadConfig() -> SchedulerConfig {
        guard let data = try? Data(contentsOf: configURL) else {
            return SchedulerConfig()
        }
        do {
            return try JSONDecoder().decode(SchedulerConfig.self, from: data)
        } catch {
            NSLog("[Aidea] scheduler config decode failed: \(error.localizedDescription)")
            return SchedulerConfig()
        }
    }

    // MARK: - State (read / write)

    /// state を読み込む。ファイル不在 / デコード失敗時は空 state を返す。
    func loadState() -> SchedulerRunState {
        guard let data = try? Data(contentsOf: stateURL) else {
            return SchedulerRunState()
        }
        do {
            return try JSONDecoder().decode(SchedulerRunState.self, from: data)
        } catch {
            NSLog("[Aidea] scheduler state decode failed: \(error.localizedDescription)")
            return SchedulerRunState()
        }
    }

    /// state を書き出す。ディレクトリは自動作成。失敗時はログのみ (個人用アプリのため握りつぶし)。
    func saveState(_ state: SchedulerRunState) {
        let dir = stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            NSLog("[Aidea] scheduler state save failed: \(error.localizedDescription)")
        }
    }

    /// config を書き出す。ON/OFF トグルなど popover からの即時反映に使う。
    /// ディレクトリは自動作成。失敗時はログのみ。
    func saveConfig(_ config: SchedulerConfig) {
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: .atomic)
        } catch {
            NSLog("[Aidea] scheduler config save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Date helper

    /// `YYYY-MM-DD` 形式のローカル日付文字列を返す (lastRun のキー値 / 比較に使う)。
    static func dateString(for date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date)
    }
}
