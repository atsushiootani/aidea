//
//  RpcRequest.swift
//  Aidea
//

import Foundation

/// `.aidea/backchannels/rpc/req-<id>.json` をデコードした外部からの往復リクエスト。
/// スキーマは inbox と同じ `{to, message}` で、`<id>` は JSON ではなくファイル名にのみ持つ。
/// docs/specs/backchannels/rpc.md / ADR 0040
struct RpcRequest: Decodable {
    /// 宛先 Companion (index 直指定 または name 文字列マッチ)
    let to: HandoffMessage.Target
    /// 宛先 Claude にそのまま送信するプロンプト本文 (空は無効)
    let message: String
}
