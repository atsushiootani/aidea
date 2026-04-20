//
//  GitDiffSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation

/// GitDiff Session の内部状態。モードに応じた全ファイルの diff 出力を保持する。
@Observable
final class GitDiffSessionState: SessionState {
    let workspace: WorkspaceState
    weak var registry: SessionRegistry?
    var mode: GitMode = .workingChanges
    var diffOutput: String = ""
    /// ジャンプ先ファイルパス（Git ツールからの選択で設定される）
    var scrollToFile: String?
    /// Viewed 済みファイルパスの集合
    var viewedFiles: Set<String> = [] {
        didSet { notifyGitToolViewedChanged() }
    }

    /// Git ツールの OutlineView を更新させる
    private func notifyGitToolViewedChanged() {
        guard let registry else { return }
        for pane in registry.layout.allPanes {
            for id in pane.tabs where id.tool == .git {
                if let s = registry.session(for: id),
                   let gitState = s.state as? GitSessionState {
                    gitState.onViewedChanged?()
                    return
                }
            }
        }
    }
    /// 現在ビューポート中央に表示されているファイルパス。変化時に Git ツールに通知する。
    var focusedFile: String? {
        didSet {
            guard focusedFile != oldValue, let focusedFile, let registry else { return }
            // Git ツールの選択を追従させる
            notifyGitTool(focusedFile: focusedFile, registry: registry)
        }
    }

    /// Git ツールの選択を変更する
    private func notifyGitTool(focusedFile: String, registry: SessionRegistry) {
        for pane in registry.layout.allPanes {
            for id in pane.tabs where id.tool == .git {
                if let s = registry.session(for: id),
                   let gitState = s.state as? GitSessionState {
                    gitState.selectedPath = focusedFile
                    return
                }
            }
        }
    }

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// 全 diff を取得する
    func reload() {
        guard let root = workspace.projectRoot else { return }
        do {
            switch mode {
            case .workingChanges:
                diffOutput = try GitService.diffAll(cwd: root)
            case .prPreview:
                diffOutput = try GitService.diffMain(cwd: root)
            }
        } catch {
            diffOutput = "diff の取得に失敗しました: \(error.localizedDescription)"
        }
    }

    /// GitDiff がアクティブになったら WKWebView にフォーカス
    func didBecomeActive(session: Session) {
        if let view = session.focusableView {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
    }

    /// 現在の Scene 識別子 (Git ツールとは別キーで永続化するため `gitDiff:*` を返す)
    func currentScene() -> String? {
        switch mode {
        case .workingChanges: return "gitDiff:workingChanges"
        case .prPreview: return "gitDiff:prPreview"
        }
    }

    /// デフォルトのレコメンドプロンプト (Git ツールと同じ内容)
    func recommendedPrompts() -> [String] {
        switch mode {
        case .workingChanges: return ["コミットして", "プッシュして", "PRを作って"]
        case .prPreview: return ["PRをマージして", "レビューして"]
        }
    }
}
