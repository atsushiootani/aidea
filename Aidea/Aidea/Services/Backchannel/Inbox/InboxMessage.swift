//
//  InboxMessage.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/inbox/*.json` をデコードした外部入力メッセージ。
/// 外部プロセス → Companion の一方向 (返信経路なし)。
/// `to` は handoff と同じ `Target` (index 0..8 または name) を再利用する。
/// docs/specs/backchannels/inbox.md / ADR 0037
struct InboxMessage: Decodable {
    /// 宛先 Companion (index 直指定 または name 文字列マッチ)
    let to: HandoffMessage.Target
    /// 宛先 Claude にそのまま送信するプロンプト本文 (空は無効)
    let message: String
}
