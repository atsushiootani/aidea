//
//  PreviewSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import Observation

/// Preview Session の内部状態。表示中のファイル URL と、タブに表示するタイトルを持つ。
/// アクティブ Session のとき、Filer のクリックで url が更新される。
/// `focusableView` は表示中のコンテンツに応じて子ビューが動的に更新する。
@Observable
final class PreviewSessionState: SessionState {
    /// プレビュー対象のファイル URL
    var url: URL?
    /// タブに表示するタイトル。nil のときは url の lastPathComponent を使う (既定挙動)。
    /// Kit から開くときに Skill/Command 名などをセットする。
    var title: String?
    /// キー入力を受け取るべき NSView。子ビュー (NSTextPreview / DrawioEditor 等) が
    /// 自身の NSView を生成した時点でここに書き込む。nil = 純 SwiftUI コンテンツ。
    /// Session への弱参照 (focusableView 報告用)。createSession 後にセットされる。
    @ObservationIgnored weak var session: Session?

    /// Preview がアクティブになったら、現在の focusableView で First Responder を取る
    func didBecomeActive(session: Session) {
        // focusableView は子ビューが事前にセット済み。
        // Session.activate() が makeFirstResponder を呼ぶ。
    }

    /// 子ビューが focusableView を報告するヘルパー
    func setFocusableView(_ view: NSView?) {
        session?.focusableView = view
    }
}
