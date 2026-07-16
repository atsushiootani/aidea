//
//  RpcWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/rpc/req-*.json` を FSEvents で再帰監視し、外部からの往復リクエストを通知する。
/// 親ディレクトリ名が `rpc` かつファイル名が `req-` で始まる `*.json` のみを対象とするため、
/// inbox / handoff 等とは弾き合わない。Companion が書く `res-*.txt` は監視しない (外部プロセスが読む)。
/// ライブ FSEvents のみを処理し、**起動時の再スキャンは行わない** (古いリクエストの誤再送を避ける)。
/// ファイルは削除せず残す (ADR 0024)。設計は InboxWatcher を踏襲。
/// docs/specs/backchannels/rpc.md
final class RpcWatcher {
    private let watcher = FileWatcher()

    /// リクエストのパースに成功したときのコールバック (リクエスト, ファイル名から抽出した id, 元ファイル URL)
    var onRequest: ((RpcRequest, String, URL) -> Void)?
    /// パース失敗・必須フィールド欠落など解釈できないリクエストを受けたときのコールバック
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

    /// FSEvents の変更通知を処理する。`rpc/req-*.json` を抽出してデコードする。
    /// - 親が `rpc` 以外 / `req-` 始まりでない / 拡張子が json 以外は無視 (他 Watcher・res の担当外)
    /// - デバッグ目的で内容を後から確認できるよう、処理後もファイルは残す。
    private func handleChanges(_ paths: Set<String>) {
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard url.pathExtension.lowercased() == "json",
                  url.lastPathComponent.hasPrefix("req-"),
                  url.deletingLastPathComponent().lastPathComponent == "rpc" else { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }

            let id = String(url.deletingPathExtension().lastPathComponent.dropFirst("req-".count))
            guard !id.isEmpty else {
                onError?("rpc の id が空です: \(url.lastPathComponent)")
                continue
            }

            guard let data = try? Data(contentsOf: url) else {
                onError?("rpc ファイルの読み込みに失敗: \(url.lastPathComponent)")
                continue
            }
            do {
                let request = try JSONDecoder().decode(RpcRequest.self, from: data)
                guard !request.message.isEmpty else {
                    onError?("rpc の message が空です: \(url.lastPathComponent)")
                    continue
                }
                onRequest?(request, id, url)
            } catch {
                onError?("rpc JSON のパースに失敗: \(error.localizedDescription) (\(url.lastPathComponent))")
            }
        }
    }

    deinit {
        stop()
    }
}
