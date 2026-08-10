//
//  StatusWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/<companion-index>/status.json` を FSEvents で監視する。
///
/// hooks (ターン境界) と Claude 自身 (自由文字列) が同じファイルを上書きするため、
/// 監視対象はこの 1 ファイルのみ。JSON が壊れている場合や `status` が空文字列の場合は
/// 空文字列として通知し、呼び出し側でフキダシを消す。
/// 仕様: docs/specs/backchannels/status.md
final class StatusWatcher {
    private let watcher = FileWatcher()

    /// status ファイル検知時のコールバック (companionIndex, status)。
    /// status が空文字列のときは「表示しない」を意味する。
    var onStatus: ((_ companionIndex: Int, _ status: String) -> Void)?

    func start(projectRoot: URL) {
        let root = projectRoot.appending(path: ".aidea/backchannels").path
        watcher.start(path: root) { [weak self] paths in
            self?.handleChanges(paths)
        }
    }

    func stop() {
        watcher.stop()
    }

    private func handleChanges(_ paths: Set<String>) {
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard url.lastPathComponent == "status.json",
                  let companionIndex = BackchannelPath.extractCompanionIndex(from: url) else { continue }

            // ファイルが消えた場合もフキダシを消す
            guard FileManager.default.fileExists(atPath: path) else {
                onStatus?(companionIndex, "")
                continue
            }
            onStatus?(companionIndex, Self.readStatus(at: url))
        }
    }

    /// status.json から表示文字列を読む。読めない / 壊れている場合は空文字列 (= 非表示)。
    static func readStatus(at url: URL) -> String {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(StatusPayload.self, from: data) else { return "" }
        return payload.status.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        stop()
    }
}

/// `status.json` のデコード用ペイロード。
struct StatusPayload: Decodable {
    let status: String
}
