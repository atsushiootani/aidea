//
//  SessionRegistry.swift
//  Aidea
//

import SwiftUI
import AppKit
import Observation
import SwiftTerm

/// Session 実体のライフサイクルを管理するレジストリ。
/// sessions 配列で全 Session を公開し、Active Pane + Active Tab から
/// Active Session を導出する。ライフサイクルコールバック (activate/deactivate)
/// を通じてフォーカス管理は各 Session の自己責務。
@Observable
final class SessionRegistry {
    /// 全 Session の一覧 (Window 全体で一意)
    @ObservationIgnored private(set) var sessions: [Session] = []

    /// 共有のワークスペース状態
    let workspace: WorkspaceState
    /// レイアウト設定
    let layout: LayoutConfig

    /// アクティブなペインの ID (SwiftUI が Tab ハイライトを追跡するために Observable)
    private var _activePaneID: UUID?
    /// Pane.activeIndex が変わったことを SwiftUI に通知するためのカウンタ
    private var _activeVersion: Int = 0

    /// アクティブ Session ID の変更履歴 (末尾が最新、重複排除済、最大 50 件)。
    /// openPreview のルーティング / Active Session Switcher (Ctrl+Tab) の表示元 / Tab クローズで除去。
    /// 永続化対象 (workspace.json v5)。
    @ObservationIgnored private(set) var activeSessionHistory: [SessionID] = []

    /// スナップショットから activeSessionHistory を一括復元する。
    /// `apply` 時の `setActiveTab` より前に呼ぶこと (順序が逆だと履歴が上書きされる)。
    /// 末尾が最新の前提を維持し、50 件キャップは保存時に保証されている。
    func restoreActiveSessionHistory(_ history: [SessionID]) {
        activeSessionHistory = history
    }

    init(workspace: WorkspaceState, layout: LayoutConfig) {
        self.workspace = workspace
        self.layout = layout
    }

    // MARK: - Active state (3 階層)

    /// アクティブなペインの ID
    var activePaneID: UUID? {
        get { _activePaneID }
    }

    /// アクティブなペイン (computed)
    var activePane: Pane? {
        guard let id = _activePaneID else { return nil }
        return layout.allPanes.first { $0.id == id }
    }

    /// アクティブな Session ID (computed: Active Pane の Active Tab から導出)
    /// _activeVersion を参照することで Pane.activeIndex 変更時にも SwiftUI が再評価する
    var activeSessionID: SessionID? {
        _ = _activeVersion
        return activePane?.activeSessionID
    }

    /// アクティブな Session (computed)
    var activeSession: Session? {
        guard let id = activeSessionID else { return nil }
        return session(for: id)
    }

    /// ペインとタブを指定してアクティブを切り替える。
    /// ライフサイクルコールバック (deactivate → activate) と activeSessionHistory 更新を一括で行う。
    /// PaneView のタブクリック、Cmd+[, Cmd+Shift+] 等の全操作がこのメソッドを経由する。
    func setActiveTab(paneID: UUID, tabIndex: Int? = nil) {
        let oldSessionID = activeSessionID

        _activePaneID = paneID
        _activeVersion &+= 1
        if let index = tabIndex, let pane = activePane {
            let clamped = max(0, min(index, pane.tabs.count - 1))
            pane.activeIndex = clamped
        }

        let newSessionID = activeSessionID
        if oldSessionID != newSessionID {
            if let oldID = oldSessionID, let oldSession = session(for: oldID) {
                oldSession.deactivate()
            }
            if let newID = newSessionID, let newSession = session(for: newID) {
                newSession.activate()
                // 履歴更新
                activeSessionHistory.removeAll { $0 == newID }
                activeSessionHistory.append(newID)
                if activeSessionHistory.count > 50 {
                    activeSessionHistory.removeFirst(activeSessionHistory.count - 50)
                }
            }
        }
    }

    /// SessionID を指定してそのセッションをアクティブにする (AppKit ビューのクリック等から呼ばれる)。
    /// 該当セッションを含むペインとタブを検索して setActiveTab を呼ぶ。
    func activateSession(_ id: SessionID) {
        for pane in layout.allPanes {
            if let index = pane.tabs.firstIndex(of: id) {
                setActiveTab(paneID: pane.id, tabIndex: index)
                return
            }
        }
    }

    /// 現在のアクティブ Session を再度 activate する。
    /// Preview のコンテンツロード完了時など、非同期に NSView が用意された後の再フォーカスに使う。
    /// `Session.activate()` → `state.didBecomeActive` → `focusBridge.activate()` の連鎖で
    /// bridge が pending 解消または即フォーカスを行う。
    func reactivateCurrentSession() {
        activeSession?.activate()
    }

    // MARK: - Session CRUD

    /// ID で Session を検索
    func session(for id: SessionID) -> Session? {
        sessions.first { $0.id == id }
    }

    /// Session を生成して一覧に追加。Tab 追加と同時に呼ばれる。
    func createSession(tool: Tool, instance: Int) -> Session {
        let id = SessionID(tool, instance: instance)
        if let existing = session(for: id) { return existing }
        let state = makeState(for: id)
        let session = Session(id: id, state: state)
        sessions.append(session)
        // Session/State 間の参照をセット
        if let web = state as? WebSessionState {
            web.sessionID = id
        }
        // AppKit 系 Session (FocusBridgeOwner 準拠) 共通: bridge が保持する NSView 配下の
        // クリックで自動アクティブ化する (AppKit ビューが SwiftUI の simultaneousGesture を
        // 握りつぶすケースの対策)。純 SwiftUI 系 (Kit 等) は SwiftUI が処理するのでスキップ。
        let weakSession = session
        let weakSelf = self
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak weakSession, weak weakSelf] event in
            guard let s = weakSession, let reg = weakSelf,
                  let owner = s.state as? FocusBridgeOwner,
                  let fv = owner.focusBridge.trackedView,
                  let clicked = event.window?.contentView?.hitTest(event.locationInWindow),
                  clicked.isDescendant(of: fv) else { return event }
            if reg.activeSessionID != s.id {
                reg.activateSession(s.id)
            }
            return event
        }
        return session
    }

    /// Session を一覧から除去。Tab クローズと同時に呼ばれる。
    /// Active Session Switcher で「既に存在しない Session」を表示しないよう、
    /// 履歴 (activeSessionHistory) からも該当 ID を除去する。
    func destroySession(_ id: SessionID) {
        sessions.removeAll { $0.id == id }
        activeSessionHistory.removeAll { $0 == id }
    }

    /// Session を取得 (なければ作成)。Tab 追加時や View 描画時に使う。
    func ensureSession(for id: SessionID) -> Session {
        if let existing = session(for: id) { return existing }
        return createSession(tool: id.tool, instance: id.instance)
    }

    // MARK: - Preview routing

    /// Filer / Kit のダブルクリック等から呼ばれる: 新しい Preview Tab を
    /// 「呼び出し元 (activeSessionID) のペイン以外」に作成する。
    func openPreview(for url: URL, title: String? = nil) {
        // 既に同じ URL を開いている Preview があればアクティブ化
        for pane in layout.allPanes {
            for (index, id) in pane.tabs.enumerated() where id.tool == .preview {
                if let s = session(for: id),
                   let preview = s.state as? PreviewSessionState,
                   preview.url == url {
                    if let title = title { preview.title = title }
                    setActiveTab(paneID: pane.id, tabIndex: index)
                    return
                }
            }
        }
        // 呼び出し元ペインを回避して配置先を決定
        let callerPane = activePane
        var targetPane: Pane?
        for id in activeSessionHistory.reversed() {
            if let pane = layout.allPanes.first(where: { $0.tabs.contains(id) }),
               pane !== callerPane {
                targetPane = pane
                break
            }
        }
        if targetPane == nil {
            targetPane = layout.allPanes.first { $0 !== callerPane }
        }
        guard let pane = targetPane else { return }

        let instance = layout.nextSessionInstance(of: .preview)
        let session = createSession(tool: .preview, instance: instance)
        let previewState = session.state as! PreviewSessionState
        previewState.url = url
        previewState.title = title
        pane.tabs.append(session.id)
        setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
    }

    /// Terminal / Claude の URL クリックから呼ばれる: 新しい Web Tab を
    /// 「呼び出し元 (activeSessionID) のペイン以外の最新ペイン」に作成する。
    /// Preview と異なり dedupe はせず **常に新規タブ** を作る。
    /// 仕様: docs/specs/tools/web.md#url-クリックルーティング-terminal--claude--web
    func openWeb(for url: URL) {
        // 呼び出し元ペインを回避して配置先を決定 (openPreview と同一アルゴリズム)
        let callerPane = activePane
        var targetPane: Pane?
        for id in activeSessionHistory.reversed() {
            if let pane = layout.allPanes.first(where: { $0.tabs.contains(id) }),
               pane !== callerPane {
                targetPane = pane
                break
            }
        }
        if targetPane == nil {
            targetPane = layout.allPanes.first { $0 !== callerPane }
        }
        guard let pane = targetPane else { return }

        let instance = layout.nextSessionInstance(of: .web)
        let session = createSession(tool: .web, instance: instance)
        (session.state as? WebSessionState)?.url = url
        pane.tabs.append(session.id)
        setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
    }

    /// Preview 内リンクから呼ばれる: 同じペインの右隣に Preview を挿入する。
    func openPreviewAsSibling(for url: URL, title: String? = nil) {
        // 既存 dedupe
        for pane in layout.allPanes {
            for (index, id) in pane.tabs.enumerated() where id.tool == .preview {
                if let s = session(for: id),
                   let preview = s.state as? PreviewSessionState,
                   preview.url == url {
                    if let title = title { preview.title = title }
                    setActiveTab(paneID: pane.id, tabIndex: index)
                    return
                }
            }
        }
        guard let callerID = activeSessionID,
              let pane = layout.allPanes.first(where: { $0.tabs.contains(callerID) }),
              let currentIndex = pane.tabs.firstIndex(of: callerID) else {
            openPreview(for: url, title: title)
            return
        }
        let instance = layout.nextSessionInstance(of: .preview)
        let session = createSession(tool: .preview, instance: instance)
        (session.state as? PreviewSessionState)?.url = url
        (session.state as? PreviewSessionState)?.title = title
        let insertIndex = currentIndex + 1
        pane.tabs.insert(session.id, at: insertIndex)
        setActiveTab(paneID: pane.id, tabIndex: insertIndex)
    }

    /// TabSlot へのファイル D&D から呼ばれる: ドロップされた slot 位置
    /// (pane + index) に新規 Preview タブを挿入する。
    /// 同じ URL の Preview が既に存在する場合は dedupe (新規作成せずアクティブ化。
    /// slot 位置への移動は行わない)。
    func openPreviewAtSlot(for url: URL, pane: Pane, index: Int, title: String? = nil) {
        for p in layout.allPanes {
            for (i, id) in p.tabs.enumerated() where id.tool == .preview {
                if let s = session(for: id),
                   let preview = s.state as? PreviewSessionState,
                   preview.url == url {
                    if let title = title { preview.title = title }
                    setActiveTab(paneID: p.id, tabIndex: i)
                    return
                }
            }
        }
        let instance = layout.nextSessionInstance(of: .preview)
        let session = createSession(tool: .preview, instance: instance)
        (session.state as? PreviewSessionState)?.url = url
        (session.state as? PreviewSessionState)?.title = title
        let clamped = max(0, min(index, pane.tabs.count))
        pane.tabs.insert(session.id, at: clamped)
        setActiveTab(paneID: pane.id, tabIndex: clamped)
    }

    /// Git ツールから GitDiff を別ペインの新規タブに開く。
    /// 既に同じファイルの GitDiff が開いていればそれをアクティブ化する。
    func openGitDiff(mode: GitMode, scrollToFile: String? = nil) {
        // dedupe: 既に GitDiff が開いていればアクティブ化
        for pane in layout.allPanes {
            for (index, id) in pane.tabs.enumerated() where id.tool == .gitDiff {
                if let s = session(for: id),
                   let state = s.state as? GitDiffSessionState {
                    state.mode = mode
                    state.scrollToFile = scrollToFile
                    state.reload()
                    setActiveTab(paneID: pane.id, tabIndex: index)
                    return
                }
            }
        }
        // 呼び出し元ペイン以外に配置
        let callerPane = activePane
        var targetPane: Pane?
        for id in activeSessionHistory.reversed() {
            if let pane = layout.allPanes.first(where: { $0.tabs.contains(id) }),
               pane !== callerPane {
                targetPane = pane
                break
            }
        }
        if targetPane == nil {
            targetPane = layout.allPanes.first { $0 !== callerPane }
        }
        guard let pane = targetPane else { return }

        let instance = layout.nextSessionInstance(of: .gitDiff)
        let session = createSession(tool: .gitDiff, instance: instance)
        let diffState = session.state as! GitDiffSessionState
        diffState.mode = mode
        diffState.scrollToFile = scrollToFile
        pane.tabs.append(session.id)
        setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
    }

    /// Markdown Preview の実行ボタンから呼ばれる。
    /// 既存 Terminal セッションがあればコマンドを送信し、なければ新規作成して送信する。
    func openTerminalAndRun(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 既存の Terminal セッションを探して送信
        for pane in layout.allPanes {
            for (index, id) in pane.tabs.enumerated() where id.tool == .terminal {
                if let s = session(for: id),
                   let terminalState = s.state as? TerminalSessionState {
                    setActiveTab(paneID: pane.id, tabIndex: index)
                    terminalState.terminalView.send(txt: trimmed + "\r")
                    return
                }
            }
        }

        // Terminal セッションがなければ新規作成
        let callerPane = activePane
        let targetPane = layout.allPanes.first { $0 !== callerPane } ?? layout.allPanes.first
        guard let pane = targetPane else { return }

        let instance = layout.nextSessionInstance(of: .terminal)
        let newSession = createSession(tool: .terminal, instance: instance)
        guard let terminalState = newSession.state as? TerminalSessionState else { return }
        pane.tabs.append(newSession.id)
        setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            terminalState.terminalView.send(txt: trimmed + "\r")
        }
    }

    /// 削除されたファイル/ディレクトリを表示していた Preview タブを閉じる
    func closePreviewsForDeleted(_ deleted: URL, isDirectory: Bool) {
        let deletedPath = deleted.path
        for pane in layout.allPanes {
            var indicesToRemove: [Int] = []
            for (idx, id) in pane.tabs.enumerated() where id.tool == .preview {
                guard let s = session(for: id),
                      let preview = s.state as? PreviewSessionState,
                      let url = preview.url else { continue }
                let matches: Bool
                if isDirectory {
                    matches = (url.path == deletedPath) || url.path.hasPrefix(deletedPath + "/")
                } else {
                    matches = (url.path == deletedPath)
                }
                if matches { indicesToRemove.append(idx) }
            }
            for idx in indicesToRemove.reversed() {
                let removed = pane.tabs[idx]
                pane.tabs.remove(at: idx)
                destroySession(removed)
            }
            if pane.tabs.isEmpty {
                pane.activeIndex = 0
            } else if pane.activeIndex >= pane.tabs.count {
                pane.activeIndex = pane.tabs.count - 1
            }
        }
    }

    /// Tab の D&D 移動
    func moveSession(_ id: SessionID, toPane target: Pane, atIndex index: Int) {
        guard let sourcePane = layout.allPanes.first(where: { $0.tabs.contains(id) }),
              let sourceIndex = sourcePane.tabs.firstIndex(of: id) else { return }
        if sourcePane === target {
            if index == sourceIndex || index == sourceIndex + 1 {
                setActiveTab(paneID: target.id, tabIndex: sourceIndex)
                return
            }
            sourcePane.tabs.remove(at: sourceIndex)
            let adjusted = sourceIndex < index ? index - 1 : index
            let clamped = max(0, min(adjusted, sourcePane.tabs.count))
            sourcePane.tabs.insert(id, at: clamped)
            setActiveTab(paneID: target.id, tabIndex: clamped)
        } else {
            sourcePane.tabs.remove(at: sourceIndex)
            if sourcePane.tabs.isEmpty {
                sourcePane.activeIndex = 0
            } else if sourcePane.activeIndex >= sourcePane.tabs.count {
                sourcePane.activeIndex = sourcePane.tabs.count - 1
            }
            let clamped = max(0, min(index, target.tabs.count))
            target.tabs.insert(id, at: clamped)
            setActiveTab(paneID: target.id, tabIndex: clamped)
        }
    }

    // MARK: - View factory

    /// SessionID に対応する SwiftUI View を返す。
    /// AnyView でラップして @ViewBuilder の分岐数増加による SwiftUI の型推論問題を回避する。
    /// Git / GitDiff 以外は本体 View の下部に `ScenePromptsEditorView` を挿入する統一パターン
    /// (仕様: docs/specs/companions/recommend-mode.md)。GitDiff は `GitDiffSessionContainer` 側で挿入済。
    func view(for id: SessionID) -> AnyView {
        let session = ensureSession(for: id)
        switch id.tool {
        case .filer:
            let state = session.state as! FilerSessionState
            return AnyView(VStack(spacing: 0) {
                FilerSessionView(state: state)
                ScenePromptsEditorView(scene: state.currentScene() ?? "filer")
            }.sessionFocusCleanup(state))
        case .kit:
            let state = session.state as! KitSessionState
            return AnyView(VStack(spacing: 0) {
                KitSessionView(state: state, sessionID: id)
                ScenePromptsEditorView(scene: state.currentScene() ?? "kit")
            }.sessionFocusCleanup(state))
        case .terminal:
            let state = session.state as! TerminalSessionState
            return AnyView(VStack(spacing: 0) {
                TerminalSessionView(state: state)
                ScenePromptsEditorView(scene: state.currentScene() ?? "terminal")
            }.sessionFocusCleanup(state))
        case .claude:
            let state = session.state as! ClaudeSessionState
            return AnyView(VStack(spacing: 0) {
                ClaudeSessionView(state: state)
                ScenePromptsEditorView(scene: state.currentScene() ?? "claude")
            }.sessionFocusCleanup(state))
        case .web:
            let state = session.state as! WebSessionState
            return AnyView(VStack(spacing: 0) {
                WebSessionView(state: state)
                ScenePromptsEditorView(scene: state.currentScene() ?? "web")
            }.sessionFocusCleanup(state))
        case .preview:
            let state = session.state as! PreviewSessionState
            return AnyView(VStack(spacing: 0) {
                PreviewSessionView(state: state, sessionID: id)
                ScenePromptsEditorView(scene: state.currentScene() ?? "preview")
            }.sessionFocusCleanup(state))
        case .git:
            let gitState = session.state as! GitSessionState
            return AnyView(VStack(spacing: 0) {
                GitSessionView(state: gitState)
                ScenePromptsEditorView(scene: gitState.currentScene() ?? "git")
            }.sessionFocusCleanup(gitState))
        case .gitDiff:
            let diffState = session.state as! GitDiffSessionState
            return AnyView(GitDiffSessionContainer(state: diffState, sessionID: id)
                              .sessionFocusCleanup(diffState))
        }
    }

    // MARK: - State factory

    /// tool に応じた SessionState インスタンスを生成する
    private func makeState(for id: SessionID) -> any SessionState {
        switch id.tool {
        case .filer:
            let state = FilerSessionState(workspace: workspace)
            state.registry = self
            return state
        case .kit:      return KitSessionState(workspace: workspace)
        case .terminal:
            let state = TerminalSessionState(workspace: workspace, instance: id.instance)
            state.registry = self
            return state
        case .claude:
            let state = ClaudeSessionState(workspace: workspace, instance: id.instance)
            state.registry = self
            return state
        case .web:
            let state = WebSessionState()
            state.registry = self
            return state
        case .preview:  return PreviewSessionState()
        case .git:
            let state = GitSessionState(workspace: workspace)
            state.registry = self
            return state
        case .gitDiff:
            let state = GitDiffSessionState(workspace: workspace)
            state.registry = self
            return state
        }
    }
}
