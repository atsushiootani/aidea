//
//  SessionFocusCleanup.swift
//  Aidea
//

import SwiftUI

extension View {
    /// 契約 C3: View 破棄時に SessionFocusBridge を介して firstResponder を解放する。
    ///
    /// Session ルートビューに 1 行で付けることで、Tab 削除・Pane 削除・Window クローズ等で
    /// Session ルートが hierarchy から外れた際に、自分配下の NSView が firstResponder に
    /// 残り続ける矛盾を防ぐ。
    ///
    /// AppKit 系 SessionState (FocusBridgeOwner 準拠) のみで効果を持つ。
    /// 純 SwiftUI 系 SessionState では no-op (SwiftUI の `.focused()` バインドが自動処理)。
    ///
    /// 仕様は `docs/specs/sessions/focus-contract.md` を参照。
    func sessionFocusCleanup(_ state: any SessionState) -> some View {
        onDisappear {
            (state as? FocusBridgeOwner)?.focusBridge.releaseIfOurs()
        }
    }
}
