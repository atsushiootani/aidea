//
//  InboxWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/inbox/*.json` を FSEvents で再帰監視し、外部からの inbox メッセージを通知する。
/// 親ディレクトリ名が `inbox` の `*.json` のみを対象とするため、Companion 別 (0..8) の
/// handoff 等とは弾き合わない。
/// ライブ FSEvents のみを処理し、**起動時の再スキャンは行わない** (古いメッセージの誤再送を避ける)。
/// ファイルは削除せず残す (ADR 0024)。設計は HandoffWatcher を踏襲。
/// docs/specs/backchannels/inbox.md
final class InboxWatcher {
    private let watcher = FileWatcher()

    /// inbox メッセージのパースに成功したときのコールバック (メッセージ, 元ファイル URL)
    var onMessage: ((InboxMessage, URL) -> Void)?
    /// パース失敗・必須フィールド欠落など解釈できないメッセージを受けたときのコールバック
    var onError: ((String) -> Void)?

    /// 監視を開始する。`.aidea/backchannels/` を再帰監視する (FSEvents のデフォルト挙動)。
    func start(projectRoot: URL) {
        let root = projectRoot.appending(path: ".aidea/backchannels").path
        watcher.start(path: root) { [weak self] paths in
            self?.handleChanges(paths)
        }
    }

    /// 監視を停止する
    func stop() {
        watcher.stop()
    }

    /// FSEvents の変更通知を処理する。`inbox/*.json` を抽出してデコードする。
    /// - 親が `inbox` 以外 / 拡張子が json 以外は無視 (他 Watcher の担当)
    /// - デバッグ目的で内容を後から確認できるよう、処理後もファイルは残す。
    private func handleChanges(_ paths: Set<String>) {
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard url.pathExtension.lowercased() == "json",
                  url.deletingLastPathComponent().lastPathComponent == "inbox" else { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }

            guard let data = try? Data(contentsOf: url) else {
                onError?("inbox ファイルの読み込みに失敗: \(url.lastPathComponent)")
                continue
            }
            do {
                let message = try JSONDecoder().decode(InboxMessage.self, from: data)
                guard !message.message.isEmpty else {
                    onError?("inbox の message が空です: \(url.lastPathComponent)")
                    continue
                }
                onMessage?(message, url)
            } catch {
                onError?("inbox JSON のパースに失敗: \(error.localizedDescription) (\(url.lastPathComponent))")
            }
        }
    }

    deinit {
        stop()
    }
}
