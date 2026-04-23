//
//  HandoffWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/handoff-*.json` を FSEvents で監視し、
/// 検知したハンドオフメッセージを (HandoffMessage, ファイル URL) のペアでコールバックに通知する。
/// ファイルは削除せず残す (受信側 Claude が自ら読み取るため / ログ用途)。
/// 設計は SpeechWatcher を踏襲 (docs/specs/backchannels/handoff.md)。
final class HandoffWatcher {
    private let watcher = FileWatcher()
    /// ハンドオフファイルが検知されパースに成功したときのコールバック。
    /// URL は Dispatcher 側で「.aidea/backchannels/{filename} の作業をやってね」参照メッセージを組み立てるために使う。
    var onHandoff: ((HandoffMessage, URL) -> Void)?
    /// パース失敗・必須フィールド欠落など解釈できないメッセージを受けたときのコールバック
    var onError: ((String) -> Void)?

    /// 監視を開始する。projectRoot の `.aidea/backchannels/` を見る。
    func start(projectRoot: URL) {
        let dir = projectRoot.appending(path: ".aidea/backchannels").path
        watcher.start(path: dir) { [weak self] paths in
            self?.handleChanges(paths)
        }
    }

    /// 監視を停止する
    func stop() {
        watcher.stop()
    }

    /// FSEvents の変更通知を処理する。handoff-*.json を抽出してデコードする。
    /// デバッグ目的で内容を後から確認できるよう、処理後もファイルは残す。
    private func handleChanges(_ paths: Set<String>) {
        let files = paths.filter { path in
            let name = (path as NSString).lastPathComponent
            return name.hasPrefix("handoff-") && name.hasSuffix(".json")
        }
        for path in files {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)

            guard let data = try? Data(contentsOf: url) else {
                onError?("handoff ファイルの読み込みに失敗: \(url.lastPathComponent)")
                continue
            }
            do {
                let message = try JSONDecoder().decode(HandoffMessage.self, from: data)
                guard !message.message.isEmpty else {
                    onError?("handoff の message が空です: \(url.lastPathComponent)")
                    continue
                }
                onHandoff?(message, url)
            } catch {
                onError?("handoff JSON のパースに失敗: \(error.localizedDescription)")
            }
        }
    }

    deinit {
        stop()
    }
}
