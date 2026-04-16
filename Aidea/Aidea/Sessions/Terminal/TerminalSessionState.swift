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
final class TerminalSessionState: SessionState {
    let workspace: WorkspaceState
    @ObservationIgnored private var cached: PersistentTerminalView?

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// SessionRegistry への弱参照 (クリック時のアクティブ化用)
    weak var registry: SessionRegistry?

    /// Terminal がアクティブになったら terminalView にフォーカスを当てる
    func didBecomeActive(session: Session) {
        guard let view = cached else { return }
        session.focusableView = view
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
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
