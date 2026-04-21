//
//  Session.swift
//  Aidea
//

import Foundation
import AppKit
import Observation

/// Session の実体。Window 全体で管理される first-class object。
/// Tool 固有の状態 (SessionState) を保持し、ライフサイクル発火を委譲する。
///
/// AppKit 知識 (NSView / firstResponder / makeFirstResponder) は持たない。
/// フォーカス契約 (C1 / C2 / C3) は各 SessionState が SessionFocusBridge 経由で履行する。
/// 詳細は docs/specs/sessions/focus-contract.md を参照。
@Observable
final class Session: Identifiable {
    let id: SessionID
    let state: any SessionState

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
