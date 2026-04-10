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

    /// activate 時に focusableView が nil だった場合の待ち受けフラグ。
    /// setFocusableView で view がセットされた時点で自動フォーカスする。
    @ObservationIgnored private var pendingActivation = false

    /// Preview がアクティブになったら、focusableView があれば即フォーカス、
    /// なければ pendingActivation をセットして子ビュー生成を待つ。
    func didBecomeActive(session: Session) {
        pendingActivation = false
        if let view = session.focusableView {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        } else {
            pendingActivation = true
        }
    }

    func didResignActive(session: Session) {
        pendingActivation = false
    }

    /// session.focusableView が変更されたときに呼ばれる。
    /// pendingActivation 中なら自動でフォーカスを取る。
    func onFocusableViewChanged(session: Session, view: NSView?) {
        guard pendingActivation, let view = view else { return }
        pendingActivation = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak view] in
            guard let view = view else { return }
            view.window?.makeFirstResponder(view)
        }
    }
}
