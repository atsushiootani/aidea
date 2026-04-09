//
//  PreviewSessionState.swift
//  Aidea
//

import Foundation
import Observation

/// Preview Session の内部状態。表示中のファイル URL を持つ。
/// アクティブ Session のとき、Filer のクリックで url が更新される。
@Observable
final class PreviewSessionState: SessionState {
    /// プレビュー対象のファイル URL
    var url: URL?
}
