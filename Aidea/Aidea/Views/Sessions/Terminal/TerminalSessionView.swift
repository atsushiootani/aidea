//
//  TerminalSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit
import SwiftTerm

/// Terminal Session の SwiftUI View。SessionState がキャッシュする
/// PersistentTerminalView を返して再生成を防ぐ。
///
/// NSViewRepresentable 採用理由: C (外部依存が AppKit ベース) — SwiftTerm の
/// `LocalProcessTerminalView` (ADR 0006) を使うため Representable でラップする。
/// 参考: [docs/conventions/swift.md](../../../../docs/conventions/swift.md)
struct TerminalSessionView: NSViewRepresentable {
    let state: TerminalSessionState

    func makeNSView(context: Context) -> PersistentTerminalView {
        state.terminalView
    }

    func updateNSView(_ nsView: PersistentTerminalView, context: Context) {}
}
