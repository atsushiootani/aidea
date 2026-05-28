//
//  RemindScheduler.swift
//  Aidea
//

import Foundation

/// remind エントリをトリガ時刻まで保持してから SpeechQueue へ投入するスケジューラ。
/// 発火後はファイルを `.fired.txt` リネームし、Watcher 経由でこのエントリは pending から消える。
/// 過去タイムスタンプを受け取ったら警告ログを出して `.fired` リネームのみ行う (再生しない)。
/// docs/specs/backchannels/remind.md 参照。
@MainActor
final class RemindScheduler {
    /// 発火時に呼ばれる: (entry) -> Void。SpeechQueue へ enqueue する責務は呼び出し側 (RemindState) に置く。
    var onFire: ((RemindEntry) -> Void)?
    /// pending 集合の更新通知 (UI 同期用)。引数は現在の pending エントリ一覧 (時刻昇順)。
    var onPendingChanged: (([RemindEntry]) -> Void)?

    /// fileURL → 発火タイマー
    private var workItems: [URL: DispatchWorkItem] = [:]
    /// fileURL → 元エントリ (UI 表示用)
    private var entries: [URL: RemindEntry] = [:]

    /// 新規 / 既存スキャンで取り込んだエントリを登録する。
    /// 同じ URL が既に登録済みなら旧タイマーをキャンセルして上書きする。
    func register(_ entry: RemindEntry) {
        cancel(url: entry.fileURL, notify: false)

        // 既に `.fired.txt` 等にリネーム済みファイルは Watcher が弾くため、ここに来るのは未発火だけ。
        // ただしトリガ時刻が過去なら「取りこぼし」として `.fired` リネームしてスキップする。
        let delay = entry.triggerTime.timeIntervalSinceNow
        if delay <= 0 {
            NSLog("[Aidea] remind file expired (trigger=\(entry.triggerTime), now=\(Date())): \(entry.fileURL.lastPathComponent)")
            markFired(entry.fileURL)
            notifyChanged()
            return
        }

        entries[entry.fileURL] = entry
        let item = DispatchWorkItem { [weak self] in
            self?.fire(entry)
        }
        workItems[entry.fileURL] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        notifyChanged()
    }

    /// 指定 URL のタイマーをキャンセルしてエントリを忘れる。
    /// FSEvents で削除を検知したとき / OFF 切替時に呼ぶ。
    func cancel(url: URL, notify: Bool = true) {
        if let item = workItems.removeValue(forKey: url) {
            item.cancel()
        }
        entries.removeValue(forKey: url)
        if notify { notifyChanged() }
    }

    /// 全タイマーを破棄して空にする (OFF 切替・projectRoot 切替時)。
    func cancelAll() {
        for (_, item) in workItems { item.cancel() }
        workItems.removeAll()
        entries.removeAll()
        notifyChanged()
    }

    /// 現在の pending 一覧 (トリガ時刻昇順)
    func pending() -> [RemindEntry] {
        entries.values.sorted { $0.triggerTime < $1.triggerTime }
    }

    // MARK: - private

    private func fire(_ entry: RemindEntry) {
        // 発火順序: SpeechQueue 投入 → ファイル `.fired` リネーム → pending から除去
        onFire?(entry)
        markFired(entry.fileURL)
        // markFired 後の FSEvents 削除イベントで onDisappeared が呼ばれて cancel される経路もあるが、
        // 念のためここでも entries から除去する。タイマー本体は既に発火済みなので workItems を抜くだけ。
        workItems.removeValue(forKey: entry.fileURL)
        entries.removeValue(forKey: entry.fileURL)
        notifyChanged()
    }

    /// `remind-{ts}.txt` を `remind-{ts}.fired.txt` にリネームする。
    /// 元ファイルが既に消えていれば何もしない。
    private func markFired(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let name = url.lastPathComponent
        // `remind-{ts}.txt` → `remind-{ts}.fired.txt`
        guard name.hasSuffix(".txt") else { return }
        let base = String(name.dropLast(".txt".count))
        let newName = "\(base).fired.txt"
        let dest = url.deletingLastPathComponent().appending(path: newName)
        do {
            try FileManager.default.moveItem(at: url, to: dest)
        } catch {
            NSLog("[Aidea] remind fired-rename failed: \(error.localizedDescription) (\(url.path))")
        }
    }

    private func notifyChanged() {
        onPendingChanged?(pending())
    }
}
