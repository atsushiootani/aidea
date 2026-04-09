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
@Observable
final class WebSessionState: SessionState {
    var url: URL = URL(string: "https://www.apple.com")!
    @ObservationIgnored private var cached: WKWebView?

    /// View 側で参照する WKWebView (初回のみ生成)
    var webView: WKWebView {
        if let cached = cached { return cached }
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        webView.load(URLRequest(url: url))
        cached = webView
        return webView
    }
}
