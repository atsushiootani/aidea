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
final class GitSessionState: SessionState, FocusBridgeOwner {
    let workspace: WorkspaceState
    /// フォーカス契約 C1/C2/C3 を担う非永続ヘルパ (仕様は focus-contract.md)
    let focusBridge = SessionFocusBridge()
    weak var registry: SessionRegistry?

    var mode: GitMode = .workingChanges
    var treeNodes: [GitFileTreeNode] = []
    var selectedPath: String? {
        didSet {
            if selectedPath != oldValue { onSelectedPathChanged?(selectedPath) }
        }
    }
    /// OutlineView の選択を追従させるためのコールバック
    @ObservationIgnored var onSelectedPathChanged: ((String?) -> Void)?
    /// Viewed 状態が変化した時に OutlineView をリロードするコールバック
    @ObservationIgnored var onViewedChanged: (() -> Void)?
    var currentBranch: String = ""
    let baseBranch: String = "main"
    /// ファイルパス → (追加行数, 削除行数) — 未ステージ差分 / PR Preview では全体差分
    var fileStats: [String: (added: Int, deleted: Int)] = [:]
    /// ファイルパス → (追加行数, 削除行数) — ステージ済み差分のみ (Working Changes 専用)
    var stagedFileStats: [String: (added: Int, deleted: Int)] = [:]

    /// ルートレベルの表示件数上限 (デフォルト 50)
    var displayLimit: Int = 50
    /// 上限を超えて全件表示するか
    var showAll: Bool = false

    /// 表示するルートノード一覧 (displayLimit / showAll に応じてフィルタ)
    var displayedNodes: [GitFileTreeNode] {
        showAll ? treeNodes : Array(treeNodes.prefix(displayLimit))
    }

    /// 非表示のルートノードがあるか
    var hasMore: Bool { !showAll && treeNodes.count > displayLimit }

    /// 進行中のリロードを識別するためのカウンタ (古いリロード結果の上書きを防ぐ)
    @ObservationIgnored private var reloadGeneration: Int = 0

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// 現在のモードに応じて変更ファイル一覧をバックグラウンドでリロードする。
    /// git コマンドはメインスレッドをブロックしないようバックグラウンドキューで実行し、
    /// 完了後にメインスレッドで state を更新してから completion を呼ぶ。
    func reload(completion: (() -> Void)? = nil) {
        guard let root = workspace.projectRoot else {
            treeNodes = []
            completion?()
            return
        }
        reloadGeneration += 1
        let generation = reloadGeneration
        let capturedMode = mode

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var branch = ""
            var files: [GitChangedFile] = []
            var fileStats: [String: (added: Int, deleted: Int)] = [:]
            var stagedFileStats: [String: (added: Int, deleted: Int)] = [:]

            branch = (try? GitService.currentBranch(cwd: root)) ?? ""

            switch capturedMode {
            case .workingChanges:
                let stagedOutput = (try? GitService.diffCachedNameStatus(cwd: root)) ?? ""
                files += GitChangesParser.parse(stagedOutput, staged: true)
                let unstagedOutput = (try? GitService.diffNameStatus(cwd: root)) ?? ""
                files += GitChangesParser.parse(unstagedOutput, staged: false)
                let untrackedOutput = (try? GitService.untrackedFiles(cwd: root)) ?? ""
                files += GitChangesParser.parseUntracked(untrackedOutput)
                let staged = (try? GitService.numstatStaged(cwd: root)) ?? ""
                let unstaged = (try? GitService.numstatUnstaged(cwd: root)) ?? ""
                stagedFileStats = GitSessionState.parseNumstat(staged)
                fileStats = GitSessionState.parseNumstat(unstaged)
            case .prPreview:
                let output = (try? GitService.diffMainNameStatus(cwd: root)) ?? ""
                files = GitChangesParser.parse(output)
                fileStats = GitSessionState.parseNumstat((try? GitService.numstatMain(cwd: root)) ?? "")
            }

            let nodes = GitFileTreeNode.buildTree(from: files)

            DispatchQueue.main.async { [weak self] in
                guard let self, self.reloadGeneration == generation else { return }
                self.currentBranch = branch
                self.treeNodes = nodes
                self.fileStats = fileStats
                self.stagedFileStats = stagedFileStats
                self.showAll = false
                completion?()
            }
        }
    }

    /// numstat 出力をパースする (形式: "追加\t削除\tファイルパス")
    private static func parseNumstat(_ output: String) -> [String: (added: Int, deleted: Int)] {
        var result: [String: (added: Int, deleted: Int)] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 2)
            guard parts.count == 3 else { continue }
            let added = Int(parts[0]) ?? 0
            let deleted = Int(parts[1]) ?? 0
            let path = String(parts[2])
            // 同じファイルが staged + unstaged にある場合は合算
            if let existing = result[path] {
                result[path] = (existing.added + added, existing.deleted + deleted)
            } else {
                result[path] = (added, deleted)
            }
        }
        return result
    }

    /// 現在の Scene 識別子
    func currentScene() -> String? {
        switch mode {
        case .workingChanges: return "git:workingChanges"
        case .prPreview: return "git:prPreview"
        }
    }

    /// 契約 C1: bridge 経由で outlineView に firstResponder を移す。
    /// NSView 参照の登録は View 側 (GitSessionView.makeNSViewController) で行う。
    func didBecomeActive(session: Session) {
        focusBridge.activate()
    }

    /// 契約 C2: bridge 経由で自分配下の firstResponder を解放する。
    func didResignActive(session: Session) {
        focusBridge.deactivate()
    }
}
