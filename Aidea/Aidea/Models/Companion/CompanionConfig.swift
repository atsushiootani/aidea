//
//  CompanionConfig.swift
//  Aidea
//

import Foundation

/// 1 体のコンパニオン設定 + 起動状態。9 個固定 (index 0...8) で管理される。
/// `sessionID` は紐付いた Claude セッション ID。`nil` なら未起動。
struct CompanionConfig: Identifiable, Codable, Hashable {
    /// コンパニオン識別子。ヘッダ表示順とも一致 (0...8)
    let index: Int
    var name: String
    /// アイコン名。Assets のカスタム画像名 (例: "Companions/companion-1") または SF Symbols 名
    var icon: String
    /// Claude 起動後に送信する初期プロンプト
    var initialPrompt: String
    /// 紐付いた Claude セッション ID。nil なら未起動
    var sessionID: SessionID?

    /// Identifiable 準拠のため index を id とする
    var id: Int { index }
}
