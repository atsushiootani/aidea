//
//  SpeechWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/terminal-*/speech-*.txt` を FSEvents で監視し、
/// 新しいファイルを検知したらコールバックに (スピーカーID, 本文) を通知する。
/// 通知後にファイルを削除する。
final class SpeechWatcher {
    private let watcher = FileWatcher()
    private var watchPath: String?
    /// 読み上げ対象が検知されたときのコールバック。speakerId は 1 行目が数値の時だけ値が入る
    var onSpeechFile: ((_ speakerId: Int?, _ text: String) -> Void)?

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
                  let content = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            let parsed = Self.parse(content)
            guard !parsed.text.isEmpty else {
                try? FileManager.default.removeItem(atPath: path)
                continue
            }
            onSpeechFile?(parsed.speakerId, parsed.text)
            // 読み上げキューに投入後、ファイルを削除
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    /// 1 行目がスピーカーID（数値のみ）の場合は切り出し、残りを本文として返す。
    /// 数値でなければ全体を本文として扱い、speakerId は nil。
    static func parse(_ content: String) -> (speakerId: Int?, text: String) {
        guard let newlineRange = content.rangeOfCharacter(from: .newlines) else {
            // 改行なし → 1 行だけ。数値のみならスピーカー指定だけで本文なし。
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            if Int(trimmed) != nil { return (nil, "") }
            return (nil, trimmed)
        }
        let firstLine = content[..<newlineRange.lowerBound].trimmingCharacters(in: .whitespaces)
        if let id = Int(firstLine) {
            let rest = String(content[newlineRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (id, rest)
        }
        return (nil, content.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    deinit {
        stop()
    }
}
