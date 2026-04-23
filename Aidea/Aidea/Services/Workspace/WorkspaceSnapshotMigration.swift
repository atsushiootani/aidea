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

/// v7 までの companions[] エントリ (initialPrompt フィールドを保持)。
/// v8 で `CompanionConfig.initialPrompt` を削除し、内容を
/// `.aidea/claude/companions/<index>/instructions.md` に外部化したため、
/// v7 → v8 マイグレーションで本構造体経由で読み出して書き出す (ADR 0022)。
struct LegacyCompanionConfigV7: Codable {
    let index: Int
    var name: String
    var icon: String
    var initialPrompt: String
    var sessionID: SessionID?
}

/// v7 形式のワークスペーススナップショット (companions が initialPrompt を持つ)。
/// v8 で companies の型が CompanionConfig (initialPrompt なし) に変わったため、
/// v7 ファイルは本構造体で先にデコードしてから v8 に変換する。
struct LegacyWorkspaceSnapshotV7: Codable {
    let version: Int
    let layout: LayoutSnapshot
    let sessions: SessionsSnapshot
    let companions: [LegacyCompanionConfigV7]
    let recommends: [String: SceneConfig]
}
