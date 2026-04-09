//
//  TerminalSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit
import SwiftTerm

/// Terminal Session の SwiftUI View。SessionState がキャッシュする
/// LocalProcessTerminalView を返して再生成を防ぐ。
struct TerminalSessionView: NSViewRepresentable {
    let state: TerminalSessionState

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        state.terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
