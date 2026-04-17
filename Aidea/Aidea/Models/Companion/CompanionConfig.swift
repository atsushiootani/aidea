//
//  CompanionConfig.swift
//  Aidea
//

import Foundation

/// コンパニオンの設定。1 つのコンパニオンが 1 つの Claude セッションに対応する。
struct CompanionConfig: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    /// アイコン名。Assets のカスタム画像名 (例: "Companions/companion-1") または SF Symbols 名
    var icon: String
    /// Claude 起動後に送信する初期プロンプト
    var initialPrompt: String
    /// Aidea 起動時に自動で Claude セッションを開始するか
    var autoLaunch: Bool

    init(
        id: UUID = UUID(),
        name: String = "Companion",
        icon: String = "Companions/companion-1",
        initialPrompt: String = "",
        autoLaunch: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.initialPrompt = initialPrompt
        self.autoLaunch = autoLaunch
    }
}

/// コンパニオンアイコンのプリセット一覧
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
}
