//
//  TerminalSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit
import SwiftTerm

/// Terminal Session の SwiftUI View。SessionState がキャッシュする
/// PersistentTerminalView を返して再生成を防ぐ。
struct TerminalSessionView: NSViewRepresentable {
    let state: TerminalSessionState

    func makeNSView(context: Context) -> PersistentTerminalView {
        state.terminalView
    }

    func updateNSView(_ nsView: PersistentTerminalView, context: Context) {}
}
