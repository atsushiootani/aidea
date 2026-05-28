//
//  RemindEntry.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/<N>/remind-{YYYYMMDDTHHmmss}.txt` をパースした結果。
/// RemindWatcher → RemindScheduler → RemindState の間で受け渡される。
struct RemindEntry: Identifiable, Equatable {
    /// fileURL を id として使う (同一ファイルは同一エントリ)
    var id: URL { fileURL }
    let companionIndex: Int
    let triggerTime: Date
    let speakerId: Int?
    /// 読み上げ本文 (speaker ID 行を除いた残り)
    let text: String
    let fileURL: URL

    /// UI のヘッダ・一覧行に表示するプレビュー文字列。
    /// 改行を空白に潰し、不要な空白を圧縮する。
    var preview: String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return collapsed.trimmingCharacters(in: .whitespaces)
    }

    /// `HH:mm` 形式のローカル時刻文字列
    var triggerTimeShort: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: triggerTime)
    }

    static func == (lhs: RemindEntry, rhs: RemindEntry) -> Bool {
        lhs.fileURL == rhs.fileURL && lhs.triggerTime == rhs.triggerTime
    }
}
