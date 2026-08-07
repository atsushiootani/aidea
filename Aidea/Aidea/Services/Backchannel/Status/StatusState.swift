//
//  StatusState.swift
//  Aidea
//

import Foundation
import Observation

/// Backchannel status ファイル監視・フキダシ文面の合成。
/// `.aidea/backchannels/<companion-index>/status-signal.json` (hooks が書く signal) と
/// `status-{timestamp}.json` (Claude が書く label) を監視し、Companion index ごとに保持する。
/// 合成ロジックは docs/specs/companions/companion.md#フキダシ表示-issue-281 を参照。
@Observable
final class StatusState {
    /// Companion index をキーとする最新 signal
    private(set) var signals: [Int: StatusSignal] = [:]
    /// Companion index をキーとする最新 label (state が idle に戻るまで保持し続ける)
    private(set) var labels: [Int: String] = [:]

    @ObservationIgnored
    private let watcher = StatusWatcher()

    /// signal フォールバック文言のユーザ設定 (`.aidea/config/status-labels.json`)。
    @ObservationIgnored
    private var labelsConfig = StatusLabelsConfig()

    func start(projectRoot: URL) {
        labelsConfig = StatusLabelsStore(projectRoot: projectRoot).loadConfig()
        watcher.onSignalFile = { [weak self] companionIndex, signal in
            DispatchQueue.main.async {
                self?.signals[companionIndex] = signal
            }
        }
        watcher.onLabelFile = { [weak self] companionIndex, label in
            DispatchQueue.main.async {
                self?.labels[companionIndex] = label
            }
        }
        watcher.start(projectRoot: projectRoot)
    }

    func stop() {
        watcher.stop()
    }

    deinit {
        stop()
    }

    /// フキダシに表示するテキスト。label があれば state を問わず label を優先し、
    /// 無ければ signal ごとの固定フォールバック文言 (`StatusSignal.fallbackText`) を使う。
    /// signal が無い/idle のときは常に nil (呼び出し側は未起動判定を別途行う)。
    func bubbleText(for companionIndex: Int) -> String? {
        guard let signal = signals[companionIndex], signal != .idle else { return nil }
        if let label = labels[companionIndex] { return label }
        return labelsConfig.text(for: signal)
    }
}
