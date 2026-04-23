//
//  HandoffWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/<companion-index>/handoff-*.json` を FSEvents で再帰監視し、
/// 検知したハンドオフメッセージを (HandoffMessage, ファイル URL, companionIndex) のトリプルでコールバックに通知する。
/// 親ディレクトリ名 (companion-index) と JSON の `from` が一致することを検証する (ADR 0024)。
/// ファイルは削除せず残す (受信側 Claude が自ら読み取るため / 履歴保全)。
/// 設計は SpeechWatcher を踏襲 (docs/specs/backchannels/handoff.md)。
final class HandoffWatcher {
    private let watcher = FileWatcher()
    /// ハンドオフファイルが検知されパースに成功したときのコールバック。
    /// URL は Dispatcher 側で「.aidea/backchannels/<from>/{filename} の作業をやってね」を組み立てるために使う。
    /// companionIndex は親ディレクトリから解決した送信元 Companion の index (0..8)。
    var onHandoff: ((HandoffMessage, URL, Int) -> Void)?
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

    /// FSEvents の変更通知を処理する。handoff-*.json を抽出してデコードする。
    /// - 親ディレクトリが 0..8 以外 → 警告ログのみで無視
    /// - JSON の `from` と親ディレクトリの数値が不一致 → onError + ファイルは残す
    /// - デバッグ目的で内容を後から確認できるよう、処理後もファイルは残す。
    private func handleChanges(_ paths: Set<String>) {
        let files = paths.filter { path in
            let name = (path as NSString).lastPathComponent
            return name.hasPrefix("handoff-") && name.hasSuffix(".json")
        }
        for path in files {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)

            guard let companionIndex = BackchannelPath.extractCompanionIndex(from: url) else {
                NSLog("[Aidea] handoff file ignored (invalid parent dir): \(url.path)")
                continue
            }

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
                guard message.from == companionIndex else {
                    onError?("handoff の from (\(message.from)) と親ディレクトリ (\(companionIndex)) が不一致: \(url.lastPathComponent)")
                    continue
                }
                onHandoff?(message, url, companionIndex)
            } catch {
                onError?("handoff JSON のパースに失敗: \(error.localizedDescription)")
            }
        }
    }

    deinit {
        stop()
    }
}
