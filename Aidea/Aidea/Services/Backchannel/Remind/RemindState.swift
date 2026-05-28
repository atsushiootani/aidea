//
//  RemindState.swift
//  Aidea
//

import Foundation
import Observation

/// リマインド機能の ON/OFF 状態と、`.aidea/backchannels/<N>/remind-*.txt` の監視・発火フローを統括する。
/// RemindWatcher → RemindScheduler → SpeechQueue の橋渡しを担い、UI (RemindView / RemindPopoverView) は
/// `pendingReminds` / `nextPending` / `isEnabled` / `isPopoverPresented` を観測する。
/// docs/specs/backchannels/remind.md 参照。
@MainActor
@Observable
final class RemindState {
    /// リマインド機能 ON/OFF (起動時は常に true、永続化しない)
    var isEnabled: Bool = true
    /// Popover の開閉
    var isPopoverPresented: Bool = false
    /// pending エントリ (未発火・未来トリガ) を triggerTime 昇順で保持
    private(set) var pendingReminds: [RemindEntry] = []

    /// ヘッダ表示用: 次の最初の予定 1 件 (空なら nil)
    var nextPending: RemindEntry? { pendingReminds.first }

    @ObservationIgnored
    private let watcher = RemindWatcher()
    @ObservationIgnored
    private let scheduler = RemindScheduler()
    @ObservationIgnored
    private weak var speechQueue: SpeechQueue?
    @ObservationIgnored
    private var projectRoot: URL?

    /// プロジェクトルートを設定し、Watcher / Scheduler を起動する。
    /// `speechQueue` は RemindScheduler の発火時に enqueue するために保持する (弱参照)。
    func start(projectRoot: URL, speechQueue: SpeechQueue) {
        self.projectRoot = projectRoot
        self.speechQueue = speechQueue

        scheduler.onFire = { [weak self] entry in
            self?.speechQueue?.enqueue(
                entry.text,
                speakerId: entry.speakerId,
                companionIndex: entry.companionIndex
            )
        }
        scheduler.onPendingChanged = { [weak self] entries in
            self?.pendingReminds = entries
        }

        watcher.onAppeared = { [weak self] entry in
            self?.scheduler.register(entry)
        }
        watcher.onDisappeared = { [weak self] url in
            self?.scheduler.cancel(url: url)
        }

        if isEnabled {
            watcher.start(projectRoot: projectRoot)
        }
    }

    /// ON/OFF トグル
    func toggle() {
        isEnabled.toggle()
        if isEnabled {
            // 再開: Watcher を起動 (起動時スキャンで未来分を再登録)
            if let root = projectRoot {
                watcher.start(projectRoot: root)
            }
        } else {
            // 停止: Watcher を止め、全タイマーを破棄
            watcher.stop()
            scheduler.cancelAll()
        }
    }

    /// Popover からリマインドエントリを削除する (ファイル削除によるキャンセル)。
    /// FSEvents の削除イベントが追って届くので、scheduler 側の cancel も多重で走るが冪等。
    func deleteRemind(_ entry: RemindEntry) {
        do {
            try FileManager.default.removeItem(at: entry.fileURL)
            scheduler.cancel(url: entry.fileURL)
        } catch {
            NSLog("[Aidea] remind delete failed: \(error.localizedDescription) (\(entry.fileURL.path))")
        }
    }
}
