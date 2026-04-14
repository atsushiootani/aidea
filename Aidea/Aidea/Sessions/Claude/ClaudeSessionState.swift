//
//  ClaudeSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation
import SwiftTerm

/// Claude Session の内部状態。
/// Terminal と同じ PTY を起動した上で、claude コマンドと Backchannel 指示を自動送信する。
@Observable
final class ClaudeSessionState: SessionState {
    let workspace: WorkspaceState
    @ObservationIgnored private var cached: PersistentTerminalView?

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// SessionRegistry への弱参照 (クリック時のアクティブ化用)
    weak var registry: SessionRegistry?
    /// 紐付けられたコンパニオンの初期プロンプト（nil なら Backchannel 指示のみ）
    var companionPrompt: String?

    /// Frontchannel: Claude セッションにメッセージを送信する
    func sendMessage(_ message: String) {
        terminalView.send(txt: message + "\r")
    }

    /// Claude がアクティブになったら terminalView にフォーカスを当てる
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
        let reg = registry
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak terminal, weak self] event in
            if let tv = terminal,
               let reg = self?.registry,
               let clickedView = event.window?.contentView?.hitTest(event.locationInWindow),
               clickedView.isDescendant(of: tv) {
                for pane in reg.layout.allPanes {
                    for id in pane.tabs where id.tool == .claude {
                        if let s = reg.session(for: id),
                           let state = s.state as? ClaudeSessionState,
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
        cached = terminal
        autoStartClaude(terminal: terminal)
        return terminal
    }

    /// 対話シェル準備完了後に claude を起動し、Backchannel 指示を送る。
    /// send() は PTY へのキー入力なので、ユーザーが手で打ったのと同等。
    /// (ADR 0008 の非対話シェル問題を回避)
    private func autoStartClaude(terminal: PersistentTerminalView) {
        let prompt = companionPrompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            terminal.send(txt: "claude\n")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            // Backchannel 指示 + コンパニオンの初期プロンプト
            var message = ".aidea/claude/aidea.md を読んで、以降のレスポンスで従ってね"
            if let prompt, !prompt.isEmpty {
                message += "\n\n" + prompt
            }
            terminal.send(txt: message + "\r")
        }
    }
}
