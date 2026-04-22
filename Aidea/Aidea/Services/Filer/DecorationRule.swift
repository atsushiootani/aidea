//
//  DecorationRule.swift
//  Aidea
//

import Foundation

/// Filer のファイル/ディレクトリに対する装飾 (アイコン + 行背景色) を、
/// glob パターンで指定する 1 ルール。
///
/// マッチング規則・後勝ち合成・デフォルト/ユーザの分離は
/// `docs/specs/tools/filer.md#デコレーション` を参照。
///
/// 永続化 (`workspace.json` v6) のため `Codable`。
struct DecorationRule: Codable, Equatable, Hashable {
    /// glob パターン (除外ルールと同じ形式: `*` / `?` / `<basename>` / `<path>/<...>`)
    var pattern: String
    /// SF Symbol 名 (一部 Asset 名 `drawio` も可)。`nil` なら前のマッチルールの値を引き継ぐ
    var icon: String?
    /// 推奨色プリセットのキー名、または hex `#RRGGBB`。`nil` なら前のマッチルールの値を引き継ぐ
    var color: String?

    init(pattern: String, icon: String? = nil, color: String? = nil) {
        self.pattern = pattern
        self.icon = icon
        self.color = color
    }
}
