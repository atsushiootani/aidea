//
//  WorkspaceSnapshotMigration.swift
//  Aidea
//

import Foundation

/// v6 までのワークスペーススナップショット形式 (フラット構造、UUID コンパニオン、bindings 別配列)。
/// 起動時の workspace.json 読込で v7 形式デコードに失敗した場合の互換読込に使う。
struct LegacyWorkspaceSnapshotV6: Codable {
    let version: Int
    let layoutRoot: LayoutNodeSnapshot
    let previews: [PreviewSnapshot]
    let webs: [WebSnapshot]
    let filers: [LegacyFilerSnapshot]
    let kits: [KitSnapshot]
    let activePaneID: UUID?
    /// v3 以降。v2 では nil
    let companions: [LegacyCompanionConfig]?
    /// v3 以降
    let companionBindings: [LegacyCompanionBinding]?
    /// v3 以降
    let recommends: [String: SceneConfig]?
    /// v5 以降。v4 以前は nil
    let activeSessionHistory: [SessionID]?
}

/// v6 までの Filer スナップショット (excludeRules / userDecorationRules が Optional)
struct LegacyFilerSnapshot: Codable {
    let id: SessionID
    let expandedURLs: [URL]
    let excludeRules: [String]?
    let userDecorationRules: [DecorationRule]?
}

/// v6 までのコンパニオン設定 (UUID 識別)
struct LegacyCompanionConfig: Codable {
    let id: UUID
    let name: String
    let icon: String
    let initialPrompt: String
}

/// v6 までのコンパニオン ↔ セッション紐付け (別配列で保持されていた)
struct LegacyCompanionBinding: Codable {
    let companionID: UUID
    let sessionID: SessionID
}
