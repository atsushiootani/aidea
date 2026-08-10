//
//  StatusWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/<companion-index>/` 配下の 2 種類のステータスファイルを FSEvents で監視する。
///
/// - `status-signal.json`: hooks が上書きする signal ({"state": "working"|"waiting"}) — 上書き検知
/// - `status-{YYYYMMDDTHHmmss}.json`: Claude が書く label ({"label": "..."}) — 新規ファイル検知
///
/// 仕様: docs/specs/backchannels/status.md
final class StatusWatcher {
    private let watcher = FileWatcher()

    /// signal ファイル検知時のコールバック (companionIndex, signal)
    var onSignalFile: ((_ companionIndex: Int, _ signal: StatusSignal) -> Void)?
    /// label ファイル検知時のコールバック (companionIndex, label)
    var onLabelFile: ((_ companionIndex: Int, _ label: String) -> Void)?

    /// label ファイル名の厳密パターン (`status-signal.json` を誤って label と扱わないための区別)。
    /// タイムスタンプ形式は他の Backchannel ファイル (speech-*.txt 等) と同じ `YYYYMMDDTHHmmss`
    /// (`T` 区切りを含む 15 文字)。
    private static let labelFileRegex = try? NSRegularExpression(pattern: #"^status-\d{8}T\d{6}\.json$"#)

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
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            let name = url.lastPathComponent

            guard let companionIndex = BackchannelPath.extractCompanionIndex(from: url) else { continue }

            if name == "status-signal.json" {
                handleSignalFile(url: url, companionIndex: companionIndex)
            } else if isLabelFileName(name) {
                handleLabelFile(url: url, companionIndex: companionIndex)
            }
        }
    }

    private func isLabelFileName(_ name: String) -> Bool {
        guard let regex = Self.labelFileRegex else { return false }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return regex.firstMatch(in: name, range: range) != nil
    }

    private func handleSignalFile(url: URL, companionIndex: Int) {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(StatusSignalPayload.self, from: data) else { return }
        onSignalFile?(companionIndex, payload.state)
    }

    private func handleLabelFile(url: URL, companionIndex: Int) {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(StatusLabelPayload.self, from: data) else { return }
        let label = payload.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        onLabelFile?(companionIndex, label)
    }

    deinit {
        stop()
    }
}

/// `status-{timestamp}.json` のデコード用ペイロード。
struct StatusLabelPayload: Decodable {
    let label: String
}
