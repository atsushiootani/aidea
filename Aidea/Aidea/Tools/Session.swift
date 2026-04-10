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

    /// focusableView の実体。@ObservationIgnored にして @Observable macro の変換を防ぎ、
    /// 手動 computed property で setter に onFocusableViewChanged コールバックを仕込む。
    @ObservationIgnored private var _focusableView: NSView?

    /// キー入力を受け取るべき NSView。
    /// 子ビュー (NSTextView, WKWebView, FocusCatcher 等) が動的に更新する。
    /// nil のときは SwiftUI の @FocusState パスが使われる (Kit 等)。
    /// セット時に state.onFocusableViewChanged が呼ばれる。
    var focusableView: NSView? {
        get { _focusableView }
        set {
            _focusableView = newValue
            state.onFocusableViewChanged(session: self, view: newValue)
        }
    }

    init(id: SessionID, state: any SessionState) {
        self.id = id
        self.state = state
    }

    /// このセッションがアクティブになったとき呼ばれる。
    /// 何をすべきかは各 SessionState が自分で決める (Tell, Don't Ask)。
    func activate() {
        state.didBecomeActive(session: self)
    }

    /// このセッションが非アクティブになったとき呼ばれる。
    func deactivate() {
        state.didResignActive(session: self)
    }
}
