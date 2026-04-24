//
//  CompanionIconPresets.swift
//  Aidea
//

import Foundation

/// コンパニオンアイコンの静的プリセット (Assets.xcassets の対応表)。
/// コンパニオン本体の name/icon/initialPrompt のデフォルト値は
/// Bundle 同梱の `Aidea/Resources/default-workspace.json` の `companions[]` が SSoT。
enum CompanionIconPresets {
    /// カスタム画像アイコン（Assets.xcassets/Companions/ 配下）
    static let imageIcons: [String] = [
        "Companions/companion-1",
        "Companions/companion-2",
        "Companions/companion-3",
        "Companions/companion-4",
        "Companions/companion-5",
        "Companions/companion-6",
        "Companions/companion-7",
        "Companions/companion-8",
        "Companions/companion-9",
    ]

    /// サムネイル用の小サイズアイコン
    static let smallIcons: [String: String] = [
        "Companions/companion-1": "Companions/companion-1-small",
        "Companions/companion-2": "Companions/companion-2-small",
        "Companions/companion-3": "Companions/companion-3-small",
        "Companions/companion-4": "Companions/companion-4-small",
        "Companions/companion-5": "Companions/companion-5-small",
        "Companions/companion-6": "Companions/companion-6-small",
        "Companions/companion-7": "Companions/companion-7-small",
        "Companions/companion-8": "Companions/companion-8-small",
        "Companions/companion-9": "Companions/companion-9-small",
    ]

    /// 読み上げ中 (笑顔) の表情アイコン (issue #45)
    static let smileIcons: [String: String] = [
        "Companions/companion-1": "Companions/companion-1-smile",
        "Companions/companion-2": "Companions/companion-2-smile",
        "Companions/companion-3": "Companions/companion-3-smile",
        "Companions/companion-4": "Companions/companion-4-smile",
        "Companions/companion-5": "Companions/companion-5-smile",
        "Companions/companion-6": "Companions/companion-6-smile",
        "Companions/companion-7": "Companions/companion-7-smile",
        "Companions/companion-8": "Companions/companion-8-smile",
        "Companions/companion-9": "Companions/companion-9-smile",
    ]

    /// Claude 実行中 (考え中) の表情アイコン (issue #45)
    static let thinkingIcons: [String: String] = [
        "Companions/companion-1": "Companions/companion-1-thinking",
        "Companions/companion-2": "Companions/companion-2-thinking",
        "Companions/companion-3": "Companions/companion-3-thinking",
        "Companions/companion-4": "Companions/companion-4-thinking",
        "Companions/companion-5": "Companions/companion-5-thinking",
        "Companions/companion-6": "Companions/companion-6-thinking",
        "Companions/companion-7": "Companions/companion-7-thinking",
        "Companions/companion-8": "Companions/companion-8-thinking",
        "Companions/companion-9": "Companions/companion-9-thinking",
    ]

    /// 各コンパニオンのテーマカラー（タブアイコンの tint に使用）
    static let themeColors: [String: (red: Double, green: Double, blue: Double)] = [
        "Companions/companion-1": (0.3, 0.5, 1.0),    // 青
        "Companions/companion-2": (0.95, 0.55, 0.1),   // オレンジ
        "Companions/companion-3": (0.4, 0.7, 0.3),    // 緑
        "Companions/companion-4": (0.95, 0.35, 0.2),   // 赤オレンジ
        "Companions/companion-5": (0.9, 0.65, 0.15),   // 金/オレンジ
        "Companions/companion-6": (0.85, 0.4, 0.55),   // ピンク
        "Companions/companion-7": (0.6, 0.75, 0.85),   // 水色
        "Companions/companion-8": (0.4, 0.2, 0.2),    // 赤黒
        "Companions/companion-9": (0.55, 0.25, 0.75),  // 紫
    ]

    /// アイコン名がカスタム画像かどうか
    static func isImageIcon(_ name: String) -> Bool {
        name.hasPrefix("Companions/")
    }

    /// サムネイル用のアイコン名を返す（小サイズがあればそれを、なければ元のまま）
    static func thumbnailIcon(for icon: String) -> String {
        smallIcons[icon] ?? icon
    }

    /// 読み上げ中 (笑顔) のアイコン名を返す。マップに無ければ元のまま (issue #45)
    static func smileIcon(for icon: String) -> String {
        smileIcons[icon] ?? icon
    }

    /// Claude 実行中 (考え中) のアイコン名を返す。マップに無ければ元のまま (issue #45)
    static func thinkingIcon(for icon: String) -> String {
        thinkingIcons[icon] ?? icon
    }
}
