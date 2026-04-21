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
final class ClaudeSessionState: SessionState, FocusBridgeOwner {
    let workspace: WorkspaceState
    /// フォーカス契約 C1/C2/C3 を担う非永続ヘルパ (仕様は focus-contract.md)
    let focusBridge = SessionFocusBridge()
    @ObservationIgnored private var cached: PersistentTerminalView?

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// SessionRegistry への弱参照 (クリック時のアクティブ化用)
    weak var registry: SessionRegistry?
    /// 紐付けられたコンパニオンの初期プロンプト。
    /// nil または空のときは起動時に何も送信しない。
    /// initialPrompt 内で `.aidea/claude/{feature}.md` を参照することで Backchannel 機能を有効化する。
    var companionPrompt: String?

    /// Frontchannel: Claude セッションにメッセージを送信する
    func sendMessage(_ message: String) {
        terminalView.send(txt: message + "\r")
    }

    /// 契約 C1: bridge 経由で terminalView に firstResponder を移す。
    /// NSView 参照の登録は View 側 (ClaudeSessionView.makeNSView) で行う。
    /// cached が lazy 生成のため pending パターンで自動解消される。
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
        terminal.installLinkGuard(isClaudeSession: true)
        cached = terminal
        autoStartClaude(terminal: terminal)
        return terminal
    }

    /// 対話シェル準備完了後に claude を起動し、コンパニオンの initialPrompt を送る。
    /// send() は PTY へのキー入力なので、ユーザーが手で打ったのと同等。
    /// (ADR 0008 の非対話シェル問題を回避)
    private func autoStartClaude(terminal: PersistentTerminalView) {
        let prompt = companionPrompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            terminal.send(txt: "claude\n")
        }
        guard let prompt, !prompt.isEmpty else { return }
        // 本文と Enter を分離して送る。
        // Claude Code (Ink 製 TUI) は bracketed paste を有効にしており、
        // 本文と \r を一度に送ると \r も paste の一部とみなされ submit されないため、
        // 本文の入力処理が終わる間 (≈0.3s) を挟んでから \r を送って submit させる。
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            terminal.send(txt: prompt)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.3) {
            terminal.send(txt: "\r")
        }
    }
}
