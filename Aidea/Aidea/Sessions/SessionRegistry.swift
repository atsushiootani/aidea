//
//  SessionRegistry.swift
//  Aidea
//

import SwiftUI
import Observation

/// Session 実体のライフサイクルを管理するレジストリ。
/// SessionID をキーに SessionState を保持し、対応する SwiftUI View を生成する。
/// "アクティブな Session" の概念もここで集中管理する (Window 全体で常に 1 つ)。
@Observable
final class SessionRegistry {
    /// SessionID -> SessionState の保持 (型消去)
    private var states: [SessionID: any SessionState] = [:]
    /// 共有のワークスペース状態 (各 SessionState から参照される)
    let workspace: WorkspaceState
    /// 現在ウィンドウ全体でアクティブな Session の ID (常に 1 つ)
    var activeSessionID: SessionID?

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// 指定 ID の状態を取得 (なければ生成して保持)
    func state(for id: SessionID) -> any SessionState {
        if let existing = states[id] { return existing }
        let created = makeState(for: id.tool)
        states[id] = created
        return created
    }

    /// アクティブ Session が Preview ならそこにファイルを表示する。Filer から呼ばれる。
    /// アクティブが Preview 以外なら何もしない (ユーザが Preview タブを選択するまで)。
    func openInActiveSession(_ url: URL) {
        guard let id = activeSessionID,
              id.tool == .preview,
              let preview = states[id] as? PreviewSessionState else { return }
        preview.url = url
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
