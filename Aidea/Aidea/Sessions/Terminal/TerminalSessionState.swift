//
//  TerminalSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation
import SwiftTerm

/// Terminal Session の内部状態。
/// LocalProcessTerminalView を初回アクセス時に生成してキャッシュし、
/// ペイン移動やタブ切替で再生成されないようにする。
@Observable
final class TerminalSessionState: SessionState {
    let workspace: WorkspaceState
    @ObservationIgnored private var cached: LocalProcessTerminalView?

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// View 側で参照する LocalProcessTerminalView (初回のみ PTY を起動)
    var terminalView: LocalProcessTerminalView {
        if let cached = cached { return cached }
        let terminal = LocalProcessTerminalView(frame: .zero)
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
        cached = terminal
        return terminal
    }
}
