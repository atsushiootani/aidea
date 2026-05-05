//
//  OutputState.swift
//  Aidea
//

import Foundation
import Observation

/// Backchannel output ファイル監視・出力履歴管理。
/// `.aidea/backchannels/<companion-index>/output-*.txt` を監視し、
/// 検知した出力をコンパニオン別の履歴として蓄積する。
@Observable
final class OutputState {
    /// Companion index をキーとする出力履歴 (新着順)
    private(set) var history: [Int: [OutputEntry]] = [:]

    @ObservationIgnored
    private let watcher = OutputWatcher()

    func start(projectRoot: URL) {
        watcher.onOutputFile = { [weak self] companionIndex, text in
            DispatchQueue.main.async {
                let entry = OutputEntry(companionIndex: companionIndex, text: text)
                self?.history[companionIndex, default: []].insert(entry, at: 0)
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
}

struct OutputEntry: Identifiable {
    let id = UUID()
    let companionIndex: Int
    let text: String
    let date = Date()
}
