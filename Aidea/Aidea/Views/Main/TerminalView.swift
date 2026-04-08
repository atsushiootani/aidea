//
//  TerminalView.swift
//  Aidea
//

import SwiftUI
import AppKit
import SwiftTerm

/// SwiftTerm の LocalProcessTerminalView を SwiftUI から使うためのラッパ View。
/// 起動時に `zsh -l` を立ち上げ、Claude Code CLI などをそのまま実行できるようにする。
struct TerminalView: NSViewRepresentable {

    /// 起動時にカレントディレクトリにする Aidea プロジェクトルートのパス
    private static let projectRoot = "/Users/atsushiotani/PROGRAM/AI/aidea"

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        // ログインシェルとして zsh を起動。プロジェクトルートに cd してから claude を exec する。
        // exec を使うことで claude 終了時に空のシェルが残らず、そのままターミナルが終了する。
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("SHELL=/bin/zsh")
        // プロジェクトルートに cd してから対話 zsh を exec する。
        // claude は手動で起動する (非対話シェルから起動するとサードパーティ判定される問題を回避)。
        let command = "cd \(Self.projectRoot) && exec zsh -l"
        terminal.startProcess(
            executable: "/bin/zsh",
            args: ["-c", command],
            environment: env
        )
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
