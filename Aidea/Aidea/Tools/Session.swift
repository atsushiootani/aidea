//
//  Session.swift
//  Aidea
//

import Foundation
import AppKit
import Observation

/// Session の実体。Window 全体で管理される first-class object。
/// Tool 固有の状態 (SessionState) とフォーカス対象 (focusableView) を束ねる。
@Observable
final class Session: Identifiable {
    let id: SessionID
    let state: any SessionState

    /// キー入力を受け取るべき NSView。
    /// 子ビュー (NSTextView, WKWebView, FocusCatcher 等) が動的に更新する。
    /// nil のときは SwiftUI の @FocusState パスが使われる (Kit 等)。
    var focusableView: NSView?

    init(id: SessionID, state: any SessionState) {
        self.id = id
        self.state = state
    }

    /// このセッションがアクティブになったとき呼ばれる。
    /// state のライフサイクルメソッドを呼んだ後、focusableView があれば First Responder にする。
    func activate() {
        state.didBecomeActive(session: self)
        if let view = focusableView {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
    }

    /// このセッションが非アクティブになったとき呼ばれる。
    func deactivate() {
        state.didResignActive(session: self)
    }
}
