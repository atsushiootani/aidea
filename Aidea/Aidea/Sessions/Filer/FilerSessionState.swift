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

    /// デコレーションのデフォルトルール。`userDecorationRules` の前に連結され、後勝ち合成のベースになる。
    /// 永続化対象外 (Aidea 同梱の定数として常に最新を使う)。
    /// 仕様: `docs/specs/tools/filer.md#デフォルトデコレーション`
    static let defaultDecorationRules: [DecorationRule] = [
        DecorationRule(pattern: "*",                       icon: "doc"),
        DecorationRule(pattern: "*.swift",                 icon: "swift"),
        DecorationRule(pattern: "*.md",                    icon: "doc.text"),
        DecorationRule(pattern: "*.markdown",              icon: "doc.text"),
        DecorationRule(pattern: "*.json",                  icon: "doc.badge.gearshape"),
        DecorationRule(pattern: "*.yaml",                  icon: "doc.badge.gearshape"),
        DecorationRule(pattern: "*.yml",                   icon: "doc.badge.gearshape"),
        DecorationRule(pattern: "*.png",                   icon: "photo"),
        DecorationRule(pattern: "*.jpg",                   icon: "photo"),
        DecorationRule(pattern: "*.jpeg",                  icon: "photo"),
        DecorationRule(pattern: "*.gif",                   icon: "photo"),
        DecorationRule(pattern: "*.heic",                  icon: "photo"),
        DecorationRule(pattern: "*.webp",                  icon: "photo"),
        DecorationRule(pattern: "*.pdf",                   icon: "doc.richtext"),
        DecorationRule(pattern: "*.zip",                   icon: "doc.zipper"),
        DecorationRule(pattern: "*.tar",                   icon: "doc.zipper"),
        DecorationRule(pattern: "*.gz",                    icon: "doc.zipper"),
        DecorationRule(pattern: "*.sh",                    icon: "terminal"),
        DecorationRule(pattern: "*.zsh",                   icon: "terminal"),
        DecorationRule(pattern: "*.bash",                  icon: "terminal"),
        DecorationRule(pattern: "*.drawio",                icon: "drawio"),
        DecorationRule(pattern: "*.drawio.svg",            icon: "drawio")
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
    /// アイコン / 行背景色のユーザ追加デコレーションルール (workspace.json v6 に永続化)
    /// `defaultDecorationRules` の後に連結され、後勝ちで装飾を上書きする。
    /// 仕様: `docs/specs/tools/filer.md#デコレーション`
    var userDecorationRules: [DecorationRule] = []
    /// Filer 操作 (rename / move / delete / create / paste) のアンドゥ・リドゥ履歴。
    /// 履歴はメモリ上のみで永続化しない (Window 終了 / Session 破棄で消える)。
    /// 仕様: docs/specs/tools/filer.md#undolastoperation
    @ObservationIgnored
    let undoManager = UndoManager()
    /// 現在 Filer が表示しているカスタムルートディレクトリ。
    /// nil のとき workspace.projectRoot を使う (デフォルト)。永続化しない。
    /// 仕様: docs/specs/tools/filer.md#navigatetodirectory
    var customRoot: URL?
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

    /// レコメンドモード用の Scene 識別子。Filer は mode 分岐なしの単一 Scene。
    /// 仕様: docs/specs/sessions/filer.md#scene-とレコメンドプロンプト
    func currentScene() -> String? { "filer" }

    init(workspace: WorkspaceState) {
        self.workspace = workspace
        self.controller = FileTreeViewController()
        self.controller.workspace = workspace
        self.controller.owner = self
    }
}
