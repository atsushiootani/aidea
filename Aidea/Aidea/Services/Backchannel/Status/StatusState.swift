//
//  StatusState.swift
//  Aidea
//

import Foundation
import Observation

/// Backchannel status ファイル監視とフキダシ文面の保持。
/// `.aidea/backchannels/<companion-index>/status.json` を監視し、書かれている文字列を
/// Companion index ごとに保持する。hooks と Claude 自身が同じファイルを上書きするため、
/// Aidea 側は最後に書かれた文字列をそのまま表示するだけで、意味の解釈は行わない。
/// 仕様: docs/specs/backchannels/status.md
@Observable
final class StatusState {
    /// Companion index をキーとする現在のステータス文字列 (空文字列は保持しない)
    private(set) var statuses: [Int: String] = [:]

    @ObservationIgnored
    private let watcher = StatusWatcher()

    func start(projectRoot: URL) {
        watcher.onStatus = { [weak self] companionIndex, status in
            DispatchQueue.main.async {
                if status.isEmpty {
                    self?.statuses.removeValue(forKey: companionIndex)
                } else {
                    self?.statuses[companionIndex] = status
                }
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

    /// フキダシに表示するテキスト。ファイル不在 / 空文字列のときは nil
    /// (呼び出し側はセッション未起動の判定を別途行う)。
    func bubbleText(for companionIndex: Int) -> String? {
        statuses[companionIndex]
    }
}
