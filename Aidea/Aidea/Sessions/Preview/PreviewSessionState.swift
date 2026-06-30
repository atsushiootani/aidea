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
    /// 純 SwiftUI コンテンツ (markdown の view モード等) がアクティブなときの SwiftUI `.focused()` バインド用フラグ。
    /// AppKit 系コンテンツ (text / drawio / markdown の edit モード) では focusBridge が firstResponder を掴むため、
    /// そのパスでは参照されない (併設による害はない)。
    var isActive: Bool = false

    /// 手動リロード要求カウンタ (issue #241)。右クリックメニューの「リロード」で `requestReload()` が
    /// インクリメントし、各プレビュー子ビューが変化を観測してファイルを再読み込みする。
    var reloadToken: Int = 0

    /// 表示中のファイルの手動リロードを要求する。
    func requestReload() {
        reloadToken &+= 1
    }

    /// 契約 C1: bridge と isActive の両方を発火する。
    /// NSView 系コンテンツでは子ビューが setView して bridge が firstResponder を取り、
    /// 純 SwiftUI 系コンテンツでは isActive → @FocusState 経由で SwiftUI が focus を取る。
    func didBecomeActive(session: Session) {
        focusBridge.activate()
        isActive = true
    }

    /// 契約 C2: bridge と isActive の両方を解放する。
    func didResignActive(session: Session) {
        focusBridge.deactivate()
        isActive = false
    }

    /// レコメンドモード用の Scene 識別子。Preview は現行単一 Scene。
    /// 仕様: docs/specs/sessions/preview.md#scene-とレコメンドプロンプト
    func currentScene() -> String? { "preview" }
}
