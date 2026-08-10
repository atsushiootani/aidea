//
//  StatusLabelsConfig.swift
//  Aidea
//

import Foundation

/// `.aidea/config/status-labels.json` のルート表現。
/// hooks がターン境界で `status.json` に書き込む文字列をユーザがカスタマイズできる。
/// 値は hooks 設定の生成時に command へ埋め込まれるため、変更の反映には
/// Aidea の再起動と対象 Companion のセッション起動し直しが必要。
/// 仕様: docs/specs/backchannels/status.md
struct StatusLabelsConfig: Codable {
    /// ターン開始時 (`UserPromptSubmit`) に書き込む文字列
    var working: String = "作業中"
    /// ターン完了時 (`Stop`) / 入力待ち時 (`Notification`) に書き込む文字列
    var waiting: String = "要返答"

    init() {}

    /// 欠けているキーはプロパティの既定値のままにする。
    /// 合成された `init(from:)` は全キーを必須にするため、片方だけ書いた設定ファイルが
    /// デコード失敗となり**両方とも既定値に戻ってしまう**。ユーザが書いた分だけを
    /// 反映するため、キー単位で `decodeIfPresent` する。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let working = try c.decodeIfPresent(String.self, forKey: .working) {
            self.working = working
        }
        if let waiting = try c.decodeIfPresent(String.self, forKey: .waiting) {
            self.waiting = waiting
        }
    }
}
