//
//  HandoffState.swift
//  Aidea
//

import Foundation
import Observation

/// Companion 間ハンドオフ機能の状態管理 + HandoffWatcher のホスティング。
/// SpeechState と同じく AideaApp 起動時に `start(projectRoot:onDispatch:)` を呼んで有効化する。
/// ハンドオフ検知時は `onDispatch` に `(HandoffMessage, 元ファイル URL)` を渡し、実際の送信ロジック
/// (宛先解決 + Claude セッション起動/アクティブ化 + PTY へのファイル参照メッセージ送信) は呼び出し側で組み立てる
/// (docs/specs/backchannels/handoff.md)。
@Observable
final class HandoffState {
    /// UI 側で表示するエラーメッセージ (宛先未解決・パース失敗など)
    var statusMessage: String = ""
    @ObservationIgnored private let watcher = HandoffWatcher()
    @ObservationIgnored private var projectRoot: URL?

    /// 監視を開始する。`onDispatch` は HandoffMessage ごとに (メッセージ, 元ファイル URL) で呼ばれる。
    /// URL は呼び出し側が「`.aidea/backchannels/{filename} の作業をやってね`」を組み立てるのに使う。
    func start(projectRoot: URL, onDispatch: @escaping (HandoffMessage, URL) -> Void) {
        self.projectRoot = projectRoot
        watcher.onHandoff = { message, url in
            onDispatch(message, url)
        }
        watcher.onError = { [weak self] text in
            self?.reportError(text)
        }
        watcher.start(projectRoot: projectRoot)
    }

    /// 監視を停止する
    func stop() {
        watcher.stop()
    }

    /// エラーを statusMessage に反映する (UI 表示用)
    func reportError(_ text: String) {
        statusMessage = text
        NSLog("[Aidea] handoff error: \(text)")
    }

    /// エラー表示をクリアする
    func clearError() {
        statusMessage = ""
    }
}
