//
//  PreviewSessionState.swift
//  Aidea
//

import Foundation
import Observation

/// Preview Session の内部状態。表示中のファイル URL と、タブに表示するタイトルを持つ。
/// アクティブ Session のとき、Filer のクリックで url が更新される。
@Observable
final class PreviewSessionState: SessionState {
    /// プレビュー対象のファイル URL
    var url: URL?
    /// タブに表示するタイトル。nil のときは url の lastPathComponent を使う (既定挙動)。
    /// Kit から開くときに Skill/Command 名などをセットする。
    var title: String?
}
