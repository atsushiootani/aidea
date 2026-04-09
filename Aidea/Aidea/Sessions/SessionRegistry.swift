//
//  SessionRegistry.swift
//  Aidea
//

import SwiftUI
import Observation

/// Session 実体のライフサイクルを管理するレジストリ。
/// SessionID をキーに SessionState を保持し、対応する SwiftUI View を生成する。
/// "アクティブな Session" とレイアウトへの参照もここで集中管理する。
@Observable
final class SessionRegistry {
    /// SessionID -> SessionState の保持 (型消去)
    private var states: [SessionID: any SessionState] = [:]
    /// 共有のワークスペース状態 (各 SessionState から参照される)
    let workspace: WorkspaceState
    /// Tab のレイアウト設定 (新しい Preview タブ作成などで参照)
    let layout: LayoutConfig
    /// 現在ウィンドウ全体でアクティブな Session の ID (常に 1 つ)
    var activeSessionID: SessionID? {
        didSet {
            guard let id = activeSessionID, id != oldValue else { return }
            // 履歴の末尾が最新。重複は詰めて追加。最大 50 件保持
            activeHistory.removeAll { $0 == id }
            activeHistory.append(id)
            if activeHistory.count > 50 {
                activeHistory.removeFirst(activeHistory.count - 50)
            }
        }
    }
    /// activeSessionID の変更履歴 (末尾が最新)。openPreview が参照先ペインを選ぶのに使う。
    private(set) var activeHistory: [SessionID] = []

    init(workspace: WorkspaceState, layout: LayoutConfig) {
        self.workspace = workspace
        self.layout = layout
    }

    /// 指定 ID の状態を取得 (なければ生成して保持)
    func state(for id: SessionID) -> any SessionState {
        if let existing = states[id] { return existing }
        let created = makeState(for: id.tool)
        states[id] = created
        return created
    }

    /// Filer のダブルクリック等から呼ばれる: 新しい Preview Tab を
    /// 「アクティブ履歴のうち、Filer とは異なるペインに属していた最新セッションのペイン」に作成する。
    /// 該当がなければ Filer 以外の最初のペインにフォールバックする。
    func openPreview(for url: URL) {
        // 既に同じファイルを開いている Preview があれば、そのタブをアクティブ化するだけ
        for pane in layout.allPanes {
            for (index, id) in pane.tabs.enumerated() where id.tool == .preview {
                if let preview = states[id] as? PreviewSessionState, preview.url == url {
                    pane.activeIndex = index
                    activeSessionID = id
                    return
                }
            }
        }

        let filerPane = layout.allPanes.first { pane in
            pane.tabs.contains { $0.tool == .filer }
        }
        // 履歴を新しい順にたどり、Filer のペイン以外に属していた最新 Session を探す
        var targetPane: Pane?
        for id in activeHistory.reversed() {
            if let pane = layout.allPanes.first(where: { $0.tabs.contains(id) }),
               pane !== filerPane {
                targetPane = pane
                break
            }
        }
        // フォールバック: Filer ペイン以外の最初のペイン
        if targetPane == nil {
            targetPane = layout.allPanes.first { $0 !== filerPane }
        }
        guard let pane = targetPane else { return }

        let instance = layout.nextSessionInstance(of: .preview)
        let id = SessionID(.preview, instance: instance)
        let state = self.state(for: id) as! PreviewSessionState
        state.url = url
        pane.tabs.append(id)
        pane.activeIndex = pane.tabs.count - 1
        activeSessionID = id
    }

    /// tool に応じた SessionState インスタンスを生成する
    private func makeState(for tool: Tool) -> any SessionState {
        switch tool {
        case .filer:
            let state = FilerSessionState(workspace: workspace)
            state.registry = self
            return state
        case .skills:   return SkillsSessionState(workspace: workspace)
        case .commands: return CommandsSessionState(workspace: workspace)
        case .mcps:     return McpsSessionState()
        case .terminal: return TerminalSessionState(workspace: workspace)
        case .web:      return WebSessionState()
        case .preview:  return PreviewSessionState()
        }
    }

    /// SessionID に対応する SwiftUI View を返す
    @ViewBuilder
    func view(for id: SessionID) -> some View {
        let state = state(for: id)
        switch id.tool {
        case .filer:    FilerSessionView(state: state as! FilerSessionState)
        case .skills:   SkillsSessionView(state: state as! SkillsSessionState)
        case .commands: CommandsSessionView(state: state as! CommandsSessionState)
        case .mcps:     McpsSessionView(state: state as! McpsSessionState)
        case .terminal: TerminalSessionView(state: state as! TerminalSessionState)
        case .web:      WebSessionView(state: state as! WebSessionState)
        case .preview:  PreviewSessionView(state: state as! PreviewSessionState)
        }
    }
}
