//
//  KitSessionState.swift
//  Aidea
//

import Foundation
import Observation

/// Kit Tool のセクション種別。4 つのリソースカテゴリを表す。
enum KitSection: String, CaseIterable, Identifiable, Hashable {
    case agents
    case skills
    case commands
    case mcps

    var id: String { rawValue }

    /// セクションヘッダーに表示するラベル (大文字)
    var title: String {
        switch self {
        case .agents:   return "AGENTS"
        case .skills:   return "SKILLS"
        case .commands: return "COMMANDS"
        case .mcps:     return "MCP SERVERS"
        }
    }
}

/// Kit Session の内部状態。4 つの Loader と展開状態・選択を保持する。
///
/// Kit View は純 SwiftUI で、`@FocusState` + `.focusable()` で focus を取り、
/// 上下キーでの項目移動は SwiftUI の `.onKeyPress` で実装する。
///
/// 自動更新:
/// `FileWatcher` を 1 つ保持し、`~/.claude/` と `<projectRoot>/.claude/` を監視する。
/// 外部での変更を検知したら 200ms デバウンス後に `reloadAll()` を呼び、4 Loader を再読み込みする。
/// 仕様は docs/specs/tools/kit.md#自動更新 を参照。
@Observable
final class KitSessionState: SessionState {
    let workspace: WorkspaceState
    let agentsLoader = AgentsLoader()
    let skillsLoader = SkillsLoader()
    let commandsLoader = CommandsLoader()
    let mcpLoader = McpLoader()

    /// 展開中のセクション集合 (初期は全て展開)
    var expandedSections: Set<KitSection> = Set(KitSection.allCases)
    /// 展開中のサブグループキー集合 ("section.prefix" 形式)
    var expandedGroups: Set<String> = []
    /// 選択中の項目キー (`section:id`)
    var selection: String?
    /// Kit がアクティブかどうか。KitSessionView が `@FocusState` と連動させる。
    var isActive: Bool = false

    /// `~/.claude/` と `<projectRoot>/.claude/` を監視する FSEvents ラッパ。
    /// 変更検知で reloadAll() を debounce 起動する。観測対象ではないため ObservationIgnored。
    @ObservationIgnored private let watcher = FileWatcher()
    /// 直近の変更通知から 200ms 以内の追加通知は 1 回にまとめるためのデバウンス用ワークアイテム
    @ObservationIgnored private var reloadDebounce: DispatchWorkItem?
    /// 現在 watcher が監視しているパス (projectRoot 差し替え判定に使う)
    @ObservationIgnored private var watchedPaths: [String] = []

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    deinit {
        watcher.stop()
        reloadDebounce?.cancel()
    }

    /// Kit は純 SwiftUI 系 Session のため isActive フラグで SwiftUI 側に通知するだけ。
    /// SwiftUI の `.focused($isActive)` バインドが内部 NSView の firstResponder 出し入れを自動処理する。
    func didBecomeActive(session: Session) {
        isActive = true
    }

    func didResignActive(session: Session) {
        isActive = false
    }

    /// レコメンドモード用の Scene 識別子。Kit は単一 Scene (section 分岐なし)。
    /// 仕様: docs/specs/sessions/kit.md#scene-とレコメンドプロンプト
    func currentScene() -> String? { "kit" }

    /// 4 Loader を projectRoot で一括再読み込みする。FSEvents 通知や `onAppear` から呼ばれる。
    func reloadAll() {
        agentsLoader.reload(projectRoot: workspace.projectRoot)
        skillsLoader.reload(projectRoot: workspace.projectRoot)
        commandsLoader.reload(projectRoot: workspace.projectRoot)
        mcpLoader.reload()
    }

    /// 現在の projectRoot に合わせて FileWatcher の監視対象を更新する。
    /// 監視対象パスが変わっていなければ何もしない (重複 start 防止)。
    /// KitSessionView の `onAppear` / `onChange(workspace.projectRoot)` から呼ばれる。
    func ensureWatcherStarted() {
        let paths = currentWatchPaths()
        guard paths != watchedPaths else { return }
        watchedPaths = paths
        watcher.start(paths: paths) { [weak self] _ in
            self?.scheduleReload()
        }
    }

    /// 監視すべきパス一覧を組み立てる。存在しないディレクトリは除外する (FSEvents が失敗するため)。
    private func currentWatchPaths() -> [String] {
        var paths: [String] = []
        let userClaude = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude", directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: userClaude.path) {
            paths.append(userClaude.path)
        }
        if let project = workspace.projectRoot {
            let projectClaude = project.appending(path: ".claude", directoryHint: .isDirectory)
            if FileManager.default.fileExists(atPath: projectClaude.path) {
                paths.append(projectClaude.path)
            }
        }
        return paths
    }

    /// 200ms デバウンスで reloadAll を発火する。連続イベントでの過剰 reload を防ぐ。
    private func scheduleReload() {
        reloadDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reloadAll()
        }
        reloadDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}
