//
//  PreviewSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation

/// Preview Session の内部状態。表示中のファイル URL と、タブに表示するタイトルを持つ。
/// アクティブ Session のとき、Filer のクリックで url が更新される。
/// コンテンツ種別ごとに子ビュー (NSTextPreview / DrawioStaticView / MarkdownContainer 等)
/// が focusBridge.setView を呼ぶことで、bridge が NSView 参照を追従する。
/// 純 SwiftUI コンテンツ (image) では setView(nil) を呼び、SwiftUI .focused() パスに委譲する。
@Observable
final class PreviewSessionState: SessionState, FocusBridgeOwner {
    /// フォーカス契約 C1/C2/C3 を担う非永続ヘルパ (仕様は focus-contract.md)。
    /// pending パターンは bridge 内に集約済のため、本 state は自前の pending フラグを持たない。
    let focusBridge = SessionFocusBridge()
    /// プレビュー対象のファイル URL
    var url: URL?
    /// タブに表示するタイトル。nil のときは url の lastPathComponent を使う (既定挙動)。
    /// Kit から開くときに Skill/Command 名などをセットする。
    var title: String?
    /// Session への弱参照 (focusableView 報告用)。createSession 後にセットされる。
    @ObservationIgnored weak var session: Session?

    /// 契約 C1: bridge 経由で現在の子ビュー NSView に firstResponder を移す。
    /// 子ビューがまだ setView していない場合は bridge が pending を立てて待機する。
    func didBecomeActive(session: Session) {
        focusBridge.activate()
    }

    /// 契約 C2: bridge 経由で自分配下の firstResponder を解放する。
    func didResignActive(session: Session) {
        focusBridge.deactivate()
    }
}
