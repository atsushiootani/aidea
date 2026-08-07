//
//  StatusSignal.swift
//  Aidea
//

import Foundation

/// `status-signal.json` (`{"state": "..."}`) の `state`。hooks が上書きする信頼できる信号
/// (working/waiting) と、Aidea 側で導出する idle の 3 値 (docs/specs/backchannels/status.md)。
enum StatusSignal: String, Decodable {
    case working
    case waiting
    case idle
}

/// `status-signal.json` のデコード用ペイロード。
struct StatusSignalPayload: Decodable {
    let state: StatusSignal
}
