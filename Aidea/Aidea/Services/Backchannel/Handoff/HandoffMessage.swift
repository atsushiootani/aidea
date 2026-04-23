//
//  HandoffMessage.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/handoff-*.json` をデコードした Companion 間ハンドオフメッセージ。
/// `to` は宛先 Companion の index (0..8) または name のどちらでも受け付ける (docs/specs/backchannels/handoff.md)。
struct HandoffMessage: Decodable {
    /// 宛先・送信元の指定方法。Int なら index 直指定、String なら name 文字列マッチ。
    enum Target: Decodable {
        case index(Int)
        case name(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let i = try? container.decode(Int.self) {
                self = .index(i)
                return
            }
            let s = try container.decode(String.self)
            self = .name(s)
        }
    }

    /// 送信元 Companion の識別子 (任意、UI/ログ用途のみで解決には使わない)
    let from: Target?
    /// 宛先 Companion の識別子 (必須)
    let to: Target
    /// ハンドオフの種別ラベル (例: implement / review)。UI/ログ用途のみ
    let task: String?
    /// 宛先 Claude にそのまま送信する本文
    let message: String
}
