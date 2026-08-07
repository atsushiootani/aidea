//
//  StatusLabelsConfig.swift
//  Aidea
//

import Foundation

/// `.aidea/config/status-labels.json` のルート表現。
/// label (Claude が明示的に書く自由文字列) が無いときに signal (working/waiting) の
/// フォールバックとして表示する文言をユーザが自由にカスタマイズできる。
/// idle はフキダシ自体を表示しないため対象外。
/// 仕様: docs/specs/backchannels/status.md
struct StatusLabelsConfig: Codable {
    var working: String = "working"
    var waiting: String = "waiting"

    /// signal に対応するフォールバック文言。idle は常に nil (フキダシ非表示)。
    func text(for signal: StatusSignal) -> String? {
        switch signal {
        case .working: return working
        case .waiting: return waiting
        case .idle: return nil
        }
    }
}
