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

/// Filer Session の永続化対象 (展開ディレクトリ一覧)
struct FilerSnapshot: Codable {
    let id: SessionID
    let expandedURLs: [URL]
}

/// Kit Session の永続化対象 (セクション・サブグループの開閉状態)
struct KitSnapshot: Codable {
    let id: SessionID
    /// 展開中のセクション (KitSection.rawValue)
    let expandedSections: [String]
    /// 展開中のサブグループキー ("section.prefix" 形式)
    let expandedGroups: [String]
}
