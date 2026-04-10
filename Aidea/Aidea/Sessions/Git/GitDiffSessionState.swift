//
//  GitDiffSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation

/// GitDiff Session の内部状態。ファイルパスと diff 出力テキストを保持する。
@Observable
final class GitDiffSessionState: SessionState {
    let workspace: WorkspaceState
    var filePath: String = ""
    var mode: GitMode = .workingChanges
    var isUntracked: Bool = false
    var isStaged: Bool = false
    var diffOutput: String = ""

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// diff を取得する
    func reload() {
        guard let root = workspace.projectRoot else { return }
        do {
            if isUntracked {
                diffOutput = try GitService.diffUntracked(filePath, cwd: root)
            } else if isStaged {
                diffOutput = try GitService.diffCachedFile(filePath, cwd: root)
            } else {
                switch mode {
                case .workingChanges:
                    diffOutput = try GitService.diffFile(filePath, cwd: root)
                case .prPreview:
                    diffOutput = try GitService.diffMainFile(filePath, cwd: root)
                }
            }
        } catch {
            diffOutput = "diff の取得に失敗しました: \(error.localizedDescription)"
        }
    }

    /// ハンク (パッチ) を逆適用して変更を破棄する
    func discardHunk(_ hunkPatch: String) throws {
        guard let root = workspace.projectRoot else { return }
        try GitService.applyReverse(patch: hunkPatch, cwd: root)
        reload() // 更新
    }

    /// GitDiff がアクティブになったら WKWebView にフォーカス
    func didBecomeActive(session: Session) {
        if let view = session.focusableView {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
    }
}
