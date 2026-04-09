//
//  WebSessionView.swift
//  Aidea
//

import SwiftUI
import WebKit

/// Web Session の SwiftUI View。SessionState がキャッシュする WKWebView を返す。
struct WebSessionView: NSViewRepresentable {
    let state: WebSessionState

    func makeNSView(context: Context) -> WKWebView {
        state.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != state.url {
            nsView.load(URLRequest(url: state.url))
        }
    }
}
