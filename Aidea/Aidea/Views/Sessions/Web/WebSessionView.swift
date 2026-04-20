//
//  WebSessionView.swift
//  Aidea
//

import SwiftUI
import WebKit

/// Web Session の SwiftUI View。SessionState がキャッシュする WKWebView を返す。
///
/// NSViewRepresentable 採用理由: C (外部依存が AppKit ベース) — WKWebView は
/// SwiftUI に等価 API が存在しないため、Representable で閉じ込める。
/// 参考: [docs/conventions/swift.md](../../../../docs/conventions/swift.md)
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
