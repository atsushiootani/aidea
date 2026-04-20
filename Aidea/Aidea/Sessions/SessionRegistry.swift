//
//  SessionRegistry.swift
//  Aidea
//

import SwiftUI
import AppKit
import Observation

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

    /// アクティブ Session ID の変更履歴 (末尾が最新)。openPreview のルーティングに使う。
    @ObservationIgnored private(set) var activeHistory: [SessionID] = []

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
    /// ライフサイクルコールバック (deactivate → activate) と activeHistory 更新を一括で行う。
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
                activeHistory.removeAll { $0 == newID }
                activeHistory.append(newID)
                if activeHistory.count > 50 {
                    activeHistory.removeFirst(activeHistory.count - 50)
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

    /// 現在のアクティブ Session を再度 activate する (focusableView 変更後の再フォーカス用)
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
        let state = makeState(for: tool)
        let session = Session(id: id, state: state)
        sessions.append(session)
        // Session/State 間の参照をセット
        if let preview = state as? PreviewSessionState {
            preview.session = session
        }
        if let web = state as? WebSessionState {
            web.sessionID = id
        }
        // Preview / Web / Terminal 以外でも共通: focusableView 配下のクリックでアクティブ化
        // (AppKit ビューが SwiftUI の simultaneousGesture を握りつぶすケースの対策)
        let weakSession = session
        let weakSelf = self
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak weakSession, weak weakSelf] event in
            guard let s = weakSession, let reg = weakSelf,
                  let fv = s.focusableView,
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
    func destroySession(_ id: SessionID) {
        sessions.removeAll { $0.id == id }
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
        for id in activeHistory.reversed() {
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
        for id in activeHistory.reversed() {
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
    func view(for id: SessionID) -> AnyView {
        let session = ensureSession(for: id)
        switch id.tool {
        case .filer:    return AnyView(FilerSessionView(session: session, state: session.state as! FilerSessionState))
        case .kit:      return AnyView(KitSessionView(state: session.state as! KitSessionState, sessionID: id))
        case .terminal: return AnyView(TerminalSessionView(state: session.state as! TerminalSessionState))
        case .claude:   return AnyView(ClaudeSessionView(state: session.state as! ClaudeSessionState))
        case .web:      return AnyView(WebSessionView(state: session.state as! WebSessionState))
        case .preview:  return AnyView(PreviewSessionView(session: session, state: session.state as! PreviewSessionState, sessionID: id))
        case .git:
            let gitState = session.state as! GitSessionState
            return AnyView(VStack(spacing: 0) {
                GitSessionView(session: session, state: gitState)
                ScenePromptsEditorView(scene: gitState.currentScene() ?? "git", defaults: gitState.recommendedPrompts())
            })
        case .gitDiff:
            let diffState = session.state as! GitDiffSessionState
            return AnyView(VStack(spacing: 0) {
                GitDiffSessionView(session: session, state: diffState)
                ScenePromptsEditorView(scene: diffState.currentScene() ?? "gitDiff", defaults: diffState.recommendedPrompts())
            })
        }
    }

    // MARK: - State factory

    /// tool に応じた SessionState インスタンスを生成する
    private func makeState(for tool: Tool) -> any SessionState {
        switch tool {
        case .filer:
            let state = FilerSessionState(workspace: workspace)
            state.registry = self
            return state
        case .kit:      return KitSessionState(workspace: workspace)
        case .terminal:
            let state = TerminalSessionState(workspace: workspace)
            state.registry = self
            return state
        case .claude:
            let state = ClaudeSessionState(workspace: workspace)
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
