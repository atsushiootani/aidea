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
        let view = state.terminalView
        // bridge に NSView 参照を登録 (SwiftUI update cycle と分離)。
        // 契約 C1 (アクティブ化時フォーカス) と SessionRegistry の click-to-activate 両方の用途。
        DispatchQueue.main.async {
            state.focusBridge.setView(view)
        }
        return view
    }

    func updateNSView(_ nsView: PersistentTerminalView, context: Context) {}
}
