//
//  CompanionConfig.swift
//  Aidea
//

import Foundation

/// 1 体のコンパニオン設定 + 起動状態。9 個固定 (index 0...8) で管理される。
/// `sessionID` は紐付いた Claude セッション ID。`nil` なら未起動。
/// 初期指示は v8 で外部ファイル (`.aidea/claude/companions/<index>/instructions.md`) に分離 (ADR 0022)。
struct CompanionConfig: Identifiable, Codable, Hashable {
    /// コンパニオン識別子。ヘッダ表示順とも一致 (0...8)
    let index: Int
    var name: String
    /// アイコン名。Assets のカスタム画像名 (例: "Companions/companion-1") または SF Symbols 名
    var icon: String
    /// 紐付いた Claude セッション ID。nil なら未起動
    var sessionID: SessionID?

    /// Identifiable 準拠のため index を id とする
    var id: Int { index }
}
