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
        // 初期 URL のロードは state.webView の lazy getter で 1 度だけ行う。
        // ここで url 不一致を検出して reload すると、ページ内遷移後に
        // ペイン移動した際に initial URL へ戻ってしまう (リロード) ため、
        // updateNSView ではあえて何もしない。
    }
}
