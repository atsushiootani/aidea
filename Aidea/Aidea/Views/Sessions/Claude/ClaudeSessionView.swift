//
//  ClaudeSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit
import SwiftTerm

/// Claude Session の SwiftUI View。ClaudeSessionState がキャッシュする
/// PersistentTerminalView を返して再生成を防ぐ。
///
/// NSViewRepresentable 採用理由: C (外部依存が AppKit ベース) — SwiftTerm の
/// `LocalProcessTerminalView` (ADR 0006) を使うため Representable でラップする。
/// 参考: [docs/conventions/swift.md](../../../../docs/conventions/swift.md)
struct ClaudeSessionView: NSViewRepresentable {
    let state: ClaudeSessionState

    /// ペインの表示中タブかどうか (PaneView が設定)。非表示タブは描画を停止する (issue #273)。
    @Environment(\.isTabVisible) private var isTabVisible

    func makeNSView(context: Context) -> PersistentTerminalView {
        let view = state.terminalView
        // bridge に NSView 参照を登録 (SwiftUI update cycle と分離)。
        // 契約 C1 (アクティブ化時フォーカス) と SessionRegistry の click-to-activate 両方の用途。
        DispatchQueue.main.async {
            state.focusBridge.setView(view)
        }
        return view
    }

    func updateNSView(_ nsView: PersistentTerminalView, context: Context) {
        // 非表示タブの描画停止 (issue #273)。表示に戻った瞬間に一括再描画される。
        nsView.setDisplaySuspended(!isTabVisible)
    }
}
