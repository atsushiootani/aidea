//
//  WorkspaceSnapshot.swift
//  Aidea
//

import Foundation

/// ワークスペース全体の保存スナップショット。
/// `workspace.json` にシリアライズされ、起動時に復元される。
struct WorkspaceSnapshot: Codable {
    /// スナップショットフォーマットのバージョン (将来のマイグレーション用)
    /// v2: レイアウトを LayoutNode ツリーで保存する形式
    /// v3: companions / bindings / recommends を統合
    /// v4: Filer Tab に excludeRules を追加 (issue #68)
    /// v5: activeSessionHistory を追加 (issue #49)
    /// v6: Filer Tab に userDecorationRules を追加 (issue #9)
    let version: Int
    /// レイアウトツリーのルートノード
    let layoutRoot: LayoutNodeSnapshot
    /// Preview Session の状態一覧
    let previews: [PreviewSnapshot]
    /// Web Session の状態一覧
    let webs: [WebSnapshot]
    /// Filer Session の状態一覧 (展開ディレクトリ等)
    let filers: [FilerSnapshot]
    /// Kit Session の状態一覧 (セクション・サブグループの開閉)
    let kits: [KitSnapshot]
    /// アクティブなペインの ID
    let activePaneID: UUID?

    // --- v3 で追加 ---

    /// コンパニオン設定一覧
    let companions: [CompanionConfig]?
    /// コンパニオン ↔ Claude セッションの紐付け
    let companionBindings: [CompanionBinding]?
    /// Scene ごとのレコメンド設定
    let recommends: [String: SceneConfig]?

    // --- v5 で追加 ---

    /// アクティブ Session 切替履歴 (末尾が最新、重複排除済、最大 50 件)。
    /// Active Session Switcher (Ctrl+Tab) の表示元データ。
    /// v4 以前のスナップショットでは nil → 空配列扱いで apply される。
    let activeSessionHistory: [SessionID]?
}

/// コンパニオン ↔ セッションの紐付け (永続化用)
struct CompanionBinding: Codable {
    let companionID: UUID
    let sessionID: SessionID
}

/// LayoutNode ツリーの永続化用表現 (再帰 enum)
indirect enum LayoutNodeSnapshot: Codable {
    case leaf(id: UUID, pane: PaneSnapshot)
    case split(id: UUID, axis: String, children: [LayoutNodeSnapshot])
}

/// 1 ペインの中身
struct PaneSnapshot: Codable {
    let paneID: UUID
    let tabs: [SessionID]
    let activeIndex: Int
}

/// Preview Session の永続化対象
struct PreviewSnapshot: Codable {
    let id: SessionID
    let url: URL?
    let title: String?
}

/// Web Session の永続化対象
struct WebSnapshot: Codable {
    let id: SessionID
    let url: URL
}

/// Filer Session の永続化対象 (展開ディレクトリ一覧 + 除外ルール + ユーザデコレーション)
struct FilerSnapshot: Codable {
    let id: SessionID
    let expandedURLs: [URL]
    /// v4 で追加。v3 以前は nil → apply 時に `FilerSessionState.defaultExcludeRules` を割り当てる
    let excludeRules: [String]?
    /// v6 で追加。v5 以前は nil → apply 時に空配列扱い (デフォルトデコレーションのみ有効)
    let userDecorationRules: [DecorationRule]?
}

/// Kit Session の永続化対象 (セクション・サブグループの開閉状態)
struct KitSnapshot: Codable {
    let id: SessionID
    /// 展開中のセクション (KitSection.rawValue)
    let expandedSections: [String]
    /// 展開中のサブグループキー ("section.prefix" 形式)
    let expandedGroups: [String]
}
