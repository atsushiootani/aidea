//
//  RemindWatcher.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/<companion-index>/remind-{YYYYMMDDTHHmmss}.txt` を FSEvents で再帰監視し、
/// 新規 / 削除を RemindScheduler に通知する。
/// 厳密な正規表現でファイル名を判定し、`.fired.txt` でリネーム済みのものは自動で除外する。
/// 起動時には watchdir 配下を 1 度走査して既存ファイルを取り込む。
/// docs/specs/backchannels/remind.md 参照。
final class RemindWatcher {
    private let watcher = FileWatcher()

    /// ファイル名: `remind-YYYYMMDDTHHmmss.txt` のみマッチ (`.fired.txt` は除外)
    private static let filenamePattern: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"^remind-\d{8}T\d{6}\.txt$"#)
    }()

    /// 新規 remind ファイルが現れたとき (FSEvents 検知 or 起動時スキャン)
    var onAppeared: ((RemindEntry) -> Void)?
    /// remind ファイルが削除 / リネームされたとき
    var onDisappeared: ((URL) -> Void)?

    /// 監視を開始する。`.aidea/backchannels/` を再帰監視し、起動時スキャンも行う。
    func start(projectRoot: URL) {
        let root = projectRoot.appending(path: ".aidea/backchannels")
        // ディレクトリが無ければ作っておく (FSEvents 開始のために存在が必要)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        watcher.start(path: root.path) { [weak self] paths in
            self?.handleChanges(paths)
        }
        scanExisting(under: root)
    }

    /// 監視を停止する (タイマー破棄は呼び出し側責務)
    func stop() {
        watcher.stop()
    }

    /// 起動時 / プロジェクト切替時に `.aidea/backchannels/<0..8>/` を走査して既存ファイルを取り込む。
    private func scanExisting(under root: URL) {
        for index in BackchannelPath.validIndexRange {
            let dir = root.appending(path: "\(index)")
            guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in contents where matches(url.lastPathComponent) {
                if let entry = parse(url: url) {
                    onAppeared?(entry)
                }
            }
        }
    }

    /// FSEvents の変更通知を処理する。
    /// - 新規ファイル (existsAtPath == true) → onAppeared
    /// - 削除 / リネーム (existsAtPath == false) → onDisappeared
    private func handleChanges(_ paths: Set<String>) {
        for path in paths {
            let url = URL(fileURLWithPath: path)
            let name = url.lastPathComponent
            guard matches(name) else {
                // パターン外 (例: `remind-*.fired.txt`, `speech-*` 等) は無視
                continue
            }
            guard BackchannelPath.extractCompanionIndex(from: url) != nil else {
                NSLog("[Aidea] remind file ignored (invalid parent dir): \(url.path)")
                continue
            }

            if FileManager.default.fileExists(atPath: path) {
                if let entry = parse(url: url) {
                    onAppeared?(entry)
                }
            } else {
                onDisappeared?(url)
            }
        }
    }

    /// `remind-YYYYMMDDTHHmmss.txt` 形式にマッチするかを判定する
    private func matches(_ name: String) -> Bool {
        let range = NSRange(name.startIndex..., in: name)
        return Self.filenamePattern.firstMatch(in: name, range: range) != nil
    }

    /// remind ファイルを読み取って RemindEntry にする。
    /// - パース失敗・空本文・トリガ時刻パース失敗 → nil (呼び出し側で握りつぶし)
    func parse(url: URL) -> RemindEntry? {
        guard let companionIndex = BackchannelPath.extractCompanionIndex(from: url) else { return nil }
        guard let triggerTime = RemindWatcher.extractTriggerTime(from: url.lastPathComponent) else {
            NSLog("[Aidea] remind file ignored (unparseable timestamp): \(url.lastPathComponent)")
            return nil
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let parsed = SpeechWatcher.parse(content)
        guard !parsed.text.isEmpty else { return nil }
        return RemindEntry(
            companionIndex: companionIndex,
            triggerTime: triggerTime,
            speakerId: parsed.speakerId,
            text: parsed.text,
            fileURL: url
        )
    }

    /// `remind-20260527T135900.txt` → Date
    /// 14 桁の `YYYYMMDDTHHmmss` をシステムタイムゾーンとして解釈する。
    static func extractTriggerTime(from filename: String) -> Date? {
        let range = NSRange(filename.startIndex..., in: filename)
        guard let match = filenamePattern.firstMatch(in: filename, range: range),
              match.range == range else { return nil }
        let prefixCount = "remind-".count
        let endIndex = filename.index(filename.startIndex, offsetBy: prefixCount + 15) // 8 + 'T' + 6
        let tsStart = filename.index(filename.startIndex, offsetBy: prefixCount)
        let tsString = String(filename[tsStart..<endIndex])
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd'T'HHmmss"
        fmt.timeZone = TimeZone.current
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.date(from: tsString)
    }

    deinit {
        stop()
    }
}
