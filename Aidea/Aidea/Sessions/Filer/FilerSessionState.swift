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
final class FilerSessionState: SessionState {
    let workspace: WorkspaceState
    /// View 側で参照する NSViewController (持ち回しで状態を維持する)
    let controller: FileTreeViewController
    /// 現在この Filer で選択されているファイル
    var selectedFile: URL?
    /// 展開されているディレクトリの URL 集合 (永続化対象、ユーザーの展開操作と同期される)
    var expandedURLs: Set<URL> = []
    /// アクティブな Session に転送するためのレジストリ参照
    weak var registry: SessionRegistry?

    init(workspace: WorkspaceState) {
        self.workspace = workspace
        self.controller = FileTreeViewController()
        self.controller.workspace = workspace
        self.controller.owner = self
    }
}
