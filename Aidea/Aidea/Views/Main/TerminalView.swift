//
//  TerminalView.swift
//  Aidea
//

import SwiftUI
import AppKit
import SwiftTerm

/// SwiftTerm の LocalProcessTerminalView を SwiftUI から使うためのラッパ View。
/// 起動時にプロジェクトルートに cd した対話 zsh を起動する。
/// projectRoot 切り替え時は親 View 側で `.id(projectRoot)` を付与して再生成する想定。
struct TerminalView: NSViewRepresentable {
    let projectRoot: URL

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        // プロジェクトルートに cd してから対話 zsh を exec する。
        // claude は手動で起動する (ADR 0008 参照)
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("SHELL=/bin/zsh")
        let command = "cd \(projectRoot.path.replacingOccurrences(of: "'", with: "'\\''")) && exec zsh -l"
        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-c", command],
            environment: env
        )
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
