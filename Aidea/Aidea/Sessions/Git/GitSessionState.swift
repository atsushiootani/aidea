//
//  GitSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation

/// Git の変更モード
enum GitMode: String, CaseIterable, Identifiable {
    case workingChanges = "Working Changes"
    case prPreview = "PR Preview"
    var id: String { rawValue }
}

/// Git Session の内部状態。モード (working/pr) + 変更ファイルツリーを保持する。
@Observable
final class GitSessionState: SessionState {
    let workspace: WorkspaceState
    weak var registry: SessionRegistry?

    var mode: GitMode = .workingChanges
    var treeNodes: [GitFileTreeNode] = []
    var selectedPath: String?

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// 現在のモードに応じて変更ファイル一覧をリロードする
    func reload() {
        guard let root = workspace.projectRoot else {
            treeNodes = []
            return
        }
        do {
            var files: [GitChangedFile] = []
            switch mode {
            case .workingChanges:
                // staged
                let stagedOutput = try GitService.diffCachedNameStatus(cwd: root)
                files += GitChangesParser.parse(stagedOutput, staged: true)
                // unstaged
                let unstagedOutput = try GitService.diffNameStatus(cwd: root)
                files += GitChangesParser.parse(unstagedOutput, staged: false)
                // untracked
                let untrackedOutput = try GitService.untrackedFiles(cwd: root)
                files += GitChangesParser.parseUntracked(untrackedOutput)
            case .prPreview:
                let output = try GitService.diffMainNameStatus(cwd: root)
                files = GitChangesParser.parse(output)
            }
            treeNodes = GitFileTreeNode.buildTree(from: files)
        } catch {
            treeNodes = []
        }
    }

    /// Git がアクティブになったら outlineView にフォーカス
    func didBecomeActive(session: Session) {
        if let view = session.focusableView {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
    }
}
