//
//  WebView.swift
//  Aidea
//

import SwiftUI
import WebKit

/// WKWebView を SwiftUI から使うためのラッパ View。
/// `isInspectable = true` を有効化し、Safari の Web Inspector から接続できるようにする。
struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
