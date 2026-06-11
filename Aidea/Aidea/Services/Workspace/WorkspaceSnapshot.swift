//
//  WorkspaceSnapshot.swift
//  Aidea
//

import Foundation

/// ワークスペース全体の保存スナップショット (v7)。
/// `workspace.json` にシリアライズされ、起動時に復元される。
/// トップレベルは 4 つの意味的グループに分かれる:
/// - `layout`     : ペイン構造 + アクティブペイン
/// - `sessions`   : 各 Session タブの永続化状態 + アクティブ履歴
/// - `companions` : 9 個固定のコンパニオン定義 + Claude セッション紐付け (sessionID 統合)
/// - `recommends` : scene → レコメンドプロンプト設定
struct WorkspaceSnapshot: Codable {
    /// スナップショットフォーマットのバージョン
    /// v7: 4 グループ化 + コンパニオン UUID → index 化 + bindings 統合 (issue #80)
    let version: Int
    let layout: LayoutSnapshot
    let sessions: SessionsSnapshot
    /// 必ず 9 要素 (index 0...8)
    let companions: [CompanionConfig]
    /// scene 識別子 → SceneConfig
    let recommends: [String: SceneConfig]
}

/// レイアウト関連 (ペイン構造 + アクティブペイン)
struct LayoutSnapshot: Codable {
    let tree: LayoutNodeSnapshot
    let activePaneID: UUID?
}

/// 各 Session タブの永続化状態 + アクティブ履歴
struct SessionsSnapshot: Codable {
    let previews: [PreviewSnapshot]
    let webs: [WebSnapshot]
    let filers: [FilerSnapshot]
    let kits: [KitSnapshot]
    /// アクティブ Session 切替履歴 (末尾が最新、重複排除済、最大 50 件)。
    /// Active Session Switcher (Ctrl+Tab) の表示元データ
    let activeHistory: [SessionID]
    /// タブのカスタム名 (ダブルクリックでリネーム)。
    /// このフィールドを持たない旧フォーマットでは nil → 空扱い (バージョン bump 不要)
    let customTitles: [CustomTitleSnapshot]?
}

/// タブカスタム名 1 件分の永続化対象 (仕様: docs/specs/sessions/ui-rules.md#タブのリネーム)
struct CustomTitleSnapshot: Codable {
    let id: SessionID
    let title: String
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
    /// v3 以前は永続化に含まれず nil 扱い → apply 時に `FilerSessionState.defaultExcludeRules` を割り当てる
    let excludeRules: [String]?
    /// v5 以前は永続化に含まれず nil 扱い → apply 時に空配列扱い (デフォルトデコレーションのみ有効)
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
