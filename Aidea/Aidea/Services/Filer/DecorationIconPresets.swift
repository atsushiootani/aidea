//
//  DecorationIconPresets.swift
//  Aidea
//

import Foundation

/// デコレーション編集 UI のアイコン列ポップアップで先頭にグリッド表示する
/// 推奨 SF Symbol 一覧 (約 20 個)。
/// 「その他...」を選ぶと SF Symbol 名を直接入力できる (任意の SF Symbol 指定可)。
/// 仕様: `docs/specs/tools/filer.md#推奨-sf-symbol`
enum DecorationIconPresets {
    static let recommended: [String] = [
        "swift",
        "doc.text",
        "doc.richtext",
        "photo",
        "terminal",
        "gear",
        "flame",
        "star",
        "bolt",
        "paperplane",
        "leaf",
        "sparkles",
        "cube",
        "paintbrush",
        "wrench.and.screwdriver",
        "book",
        "chart.bar",
        "globe",
        "ant",
        "tag"
    ]
}
