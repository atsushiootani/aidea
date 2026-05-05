//
//  OutputWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/<companion-index>/output-*.txt` を FSEvents で再帰監視し、
/// 新しいファイルを検知したらコールバックに (companionIndex, 本文) を通知する。
/// 処理後もファイルは削除しない (ADR 0024: 作業履歴として保全)。
final class OutputWatcher {
    private let watcher = FileWatcher()
    /// 出力ファイルが検知されたときのコールバック。
    /// - companionIndex: 親ディレクトリ名 (0..8) から解決した送信元 Companion の index
    /// - text: 出力本文
    var onOutputFile: ((_ companionIndex: Int, _ text: String) -> Void)?

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

    private func handleChanges(_ paths: Set<String>) {
        let outputFiles = paths.filter { path in
            let name = (path as NSString).lastPathComponent
            return name.hasPrefix("output-") && name.hasSuffix(".txt")
        }

        for path in outputFiles {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)

            guard let companionIndex = BackchannelPath.extractCompanionIndex(from: url) else {
                NSLog("[Aidea] output file ignored (invalid parent dir): \(url.path)")
                continue
            }

            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            onOutputFile?(companionIndex, text)
        }
    }

    deinit {
        stop()
    }
}
