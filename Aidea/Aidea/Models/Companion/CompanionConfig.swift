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
        icon: String = "Companions/companion-0",
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
        "Companions/companion-0",
        "Companions/companion-1",
        "Companions/companion-2",
        "Companions/companion-3",
        "Companions/companion-4",
        "Companions/companion-5",
        "Companions/companion-6",
        "Companions/companion-7",
    ]

    /// サムネイル用の小サイズアイコン（存在するもののみ）
    static let smallIcons: [String: String] = [
        "Companions/companion-0": "Companions/companion-0-small",
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
