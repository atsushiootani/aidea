//
//  SpeechWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/<companion-index>/speech-*.txt` を FSEvents で再帰監視し、
/// 新しいファイルを検知したらコールバックに (スピーカーID, companionIndex, 本文) を通知する。
/// 処理後もファイルは削除しない (ADR 0024: 作業履歴として保全)。
final class SpeechWatcher {
    private let watcher = FileWatcher()
    /// 読み上げ対象が検知されたときのコールバック。
    /// - speakerId: 1 行目が数値の時だけ値が入る
    /// - companionIndex: 親ディレクトリ名 (0..8) から解決した送信元 Companion の index
    /// - text: 読み上げ本文 (1 行目がスピーカーIDなら 2 行目以降、そうでなければ全文)
    var onSpeechFile: ((_ speakerId: Int?, _ companionIndex: Int, _ text: String) -> Void)?

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

    /// FSEvents の変更通知を処理する。
    /// - 親ディレクトリが 0..8 の整数であることを検証
    /// - 該当しないパスは警告ログのみで無視 (.aidea/backchannels/ 直下のファイルも仕様外として無視)
    private func handleChanges(_ paths: Set<String>) {
        let speechFiles = paths.filter { path in
            let name = (path as NSString).lastPathComponent
            return name.hasPrefix("speech-") && name.hasSuffix(".txt")
        }

        for path in speechFiles {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)

            guard let companionIndex = BackchannelPath.extractCompanionIndex(from: url) else {
                NSLog("[Aidea] speech file ignored (invalid parent dir): \(url.path)")
                continue
            }

            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            let parsed = Self.parse(content)
            guard !parsed.text.isEmpty else {
                // 空ファイルも削除せず無視 (履歴としてのファイルは残すが、読み上げはしない)
                continue
            }
            onSpeechFile?(parsed.speakerId, companionIndex, parsed.text)
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
