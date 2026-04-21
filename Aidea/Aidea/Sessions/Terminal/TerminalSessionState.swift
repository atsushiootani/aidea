//
//  TerminalSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation
import SwiftTerm

/// Terminal Session の内部状態。
/// PersistentTerminalView を初回アクセス時に生成してキャッシュし、
/// ペイン移動やタブ切替で再生成されないようにする。
@Observable
final class TerminalSessionState: SessionState, FocusBridgeOwner {
    let workspace: WorkspaceState
    /// フォーカス契約 C1/C2/C3 を担う非永続ヘルパ (仕様は focus-contract.md)
    let focusBridge = SessionFocusBridge()
    @ObservationIgnored private var cached: PersistentTerminalView?

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// SessionRegistry への弱参照 (クリック時のアクティブ化用)
    weak var registry: SessionRegistry?

    /// 契約 C1: bridge 経由で terminalView に firstResponder を移す。
    /// NSView 参照の登録は View 側 (TerminalSessionView.makeNSView) で行う。
    /// cached がまだ生成されていない (PTY 未起動) 場合は bridge が pending を立てて、
    /// View の makeNSView で setView される瞬間に自動フォーカスする。
    func didBecomeActive(session: Session) {
        focusBridge.activate()
    }

    /// 契約 C2: bridge 経由で自分配下の firstResponder を解放する。
    func didResignActive(session: Session) {
        focusBridge.deactivate()
    }

    /// View 側で参照する PersistentTerminalView (初回のみ PTY を起動)
    var terminalView: PersistentTerminalView {
        if let cached = cached { return cached }
        let terminal = PersistentTerminalView(frame: .zero)
        // SwiftTerm の mouseDown はオーバーライド不可 (non-open) なので
        // NSEvent local monitor でクリックを検知する
        let reg = registry
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak terminal, weak self] event in
            if let tv = terminal,
               let reg = self?.registry,
               let clickedView = event.window?.contentView?.hitTest(event.locationInWindow),
               clickedView.isDescendant(of: tv) {
                // この Terminal の SessionID を探して activate
                for pane in reg.layout.allPanes {
                    for id in pane.tabs where id.tool == .terminal {
                        if let s = reg.session(for: id),
                           let state = s.state as? TerminalSessionState,
                           state === self {
                            reg.activateSession(id)
                            break
                        }
                    }
                }
            }
            return event
        }
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("SHELL=/bin/zsh")
        let path = workspace.projectRoot?.path
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        let command = "cd '\(escaped)' && exec zsh -l"
        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-c", command],
            environment: env
        )
        terminal.installLinkGuard()
        cached = terminal
        return terminal
    }
}
