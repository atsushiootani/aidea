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
    let session: Session
    let state: TerminalSessionState

    func makeNSView(context: Context) -> PersistentTerminalView {
        let view = state.terminalView
        // SessionRegistry の NSEvent クリックハンドラ用に維持 (Phase 9 で bridge 経由に移行して撤去予定)
        session.focusableView = view
        // 契約 C1 用: bridge に NSView 参照を登録 (SwiftUI update cycle と分離)
        DispatchQueue.main.async {
            state.focusBridge.setView(view)
        }
        return view
    }

    func updateNSView(_ nsView: PersistentTerminalView, context: Context) {}
}
