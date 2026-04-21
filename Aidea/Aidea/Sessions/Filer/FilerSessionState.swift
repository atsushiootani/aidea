//
//  FilerSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation

/// Filer Session の内部状態。
/// 1 ウィンドウに 1 つだけ存在できる仕様 (PaneView 側で制約)。
@Observable
final class FilerSessionState: SessionState, FocusBridgeOwner {
    /// 除外ルールのデフォルト値。新規 Filer Session 作成時 / v3→v4 マイグレ時 / 「デフォルトに戻す」操作時に参照する。
    /// 将来 issue #80 完了時に Bundle 内 `default-workspace.json` へ移管予定。
    static let defaultExcludeRules: [String] = [
        ".git",
        "node_modules",
        "DerivedData",
        ".build",
        ".DS_Store",
        ".claude/worktrees"
    ]

    let workspace: WorkspaceState
    /// View 側で参照する NSViewController (持ち回しで状態を維持する)
    let controller: FileTreeViewController
    /// フォーカス契約 C1/C2/C3 を担う非永続ヘルパ (仕様は focus-contract.md)
    let focusBridge = SessionFocusBridge()
    /// 現在この Filer で選択されているファイル
    var selectedFile: URL?
    /// 展開されているディレクトリの URL 集合 (永続化対象、ユーザーの展開操作と同期される)
    var expandedURLs: Set<URL> = []
    /// Filer 表示・検索から除外するパターン一覧 (workspace.json v4 に永続化)
    var excludeRules: [String] = FilerSessionState.defaultExcludeRules
    /// アクティブな Session に転送するためのレジストリ参照
    weak var registry: SessionRegistry?

    /// 契約 C1: bridge 経由で outlineView に firstResponder を移す。
    /// NSView 参照の登録は View 側 (FilerSessionView.makeNSViewController) で行う。
    func didBecomeActive(session: Session) {
        focusBridge.activate()
    }

    /// 契約 C2: bridge 経由で自分配下の firstResponder を解放する。
    func didResignActive(session: Session) {
        focusBridge.deactivate()
    }

    init(workspace: WorkspaceState) {
        self.workspace = workspace
        self.controller = FileTreeViewController()
        self.controller.workspace = workspace
        self.controller.owner = self
    }
}
