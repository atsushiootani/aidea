//
//  SpeechWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/terminal-*/speech-*.txt` を FSEvents で監視し、
/// 新しいファイルを検知したらコールバックに内容を通知する。
/// 通知後にファイルを削除する。
final class SpeechWatcher {
    private let watcher = FileWatcher()
    private var watchPath: String?
    /// 読み上げ対象テキストが検知されたときのコールバック
    var onSpeechFile: ((String) -> Void)?

    /// 監視を開始する。projectRoot の .aidea/backchannels/ を監視する。
    func start(projectRoot: URL) {
        let terminalsDir = projectRoot.appending(path: ".aidea/backchannels").path
        watchPath = terminalsDir
        watcher.start(path: terminalsDir) { [weak self] paths in
            self?.handleChanges(paths)
        }
    }

    /// 監視を停止する
    func stop() {
        watcher.stop()
    }

    /// FSEvents の変更通知を処理する
    private func handleChanges(_ paths: Set<String>) {
        let speechFiles = paths.filter { path in
            let name = (path as NSString).lastPathComponent
            return name == "speech.txt" || (name.hasPrefix("speech-") && name.hasSuffix(".txt"))
        }

        for path in speechFiles {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path),
                  let content = try? String(contentsOf: url, encoding: .utf8),
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            onSpeechFile?(content.trimmingCharacters(in: .whitespacesAndNewlines))
            // 読み上げキューに投入後、ファイルを削除
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    deinit {
        stop()
    }
}
