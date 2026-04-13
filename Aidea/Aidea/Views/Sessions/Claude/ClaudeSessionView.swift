//
//  ClaudeSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit
import SwiftTerm

/// Claude Session の SwiftUI View。ClaudeSessionState がキャッシュする
/// PersistentTerminalView を返して再生成を防ぐ。
struct ClaudeSessionView: NSViewRepresentable {
    let state: ClaudeSessionState

    func makeNSView(context: Context) -> PersistentTerminalView {
        state.terminalView
    }

    func updateNSView(_ nsView: PersistentTerminalView, context: Context) {}
}
