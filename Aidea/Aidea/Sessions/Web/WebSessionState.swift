//
//  WebSessionState.swift
//  Aidea
//

import Foundation
import AppKit
import WebKit
import Observation

/// Web Session の内部状態。表示中の URL と WKWebView のキャッシュを持つ。
/// ペイン移動やタブ切替で URL と履歴が失われないようにする。
/// ナビゲーションに追従して `url` を最新の表示 URL に同期する (KVO 経由)。
@Observable
final class WebSessionState: SessionState {
    var url: URL = URL(string: "https://www.apple.com")!
    @ObservationIgnored private var cached: WKWebView?
    @ObservationIgnored private var urlObservation: NSKeyValueObservation?

    /// Web がアクティブになったら webView を focusableView に設定する
    func didBecomeActive(session: Session) {
        session.focusableView = cached
    }

    /// View 側で参照する WKWebView (初回のみ生成)
    var webView: WKWebView {
        if let cached = cached { return cached }
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        webView.load(URLRequest(url: url))
        // ナビゲーションに追従して state.url を更新する (永続化時に最新 URL を保存するため)
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
            guard let self, let newURL = webView.url, newURL != self.url else { return }
            Task { @MainActor in
                self.url = newURL
            }
        }
        cached = webView
        return webView
    }
}
