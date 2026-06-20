//
//  WebPopupController.swift
//  Aidea
//

import AppKit
import WebKit

/// サイズ指定付き `window.open` (OAuth ログイン等) を独立した `NSWindow` にホストする。
/// 子 WKWebView の `uiDelegate` を兼ね、`window.close()` (= `webViewDidClose`) で窓を閉じる。
/// SessionRegistry が生存参照として保持し、窓クローズで解放する。
///
/// 仕様: docs/specs/sessions/web.md#フローティングポップアップ窓
/// 判断: [ADR 0035](../../../docs/decisions/0035-web-window-open-tab-and-popup.md)
final class WebPopupController: NSObject, WKUIDelegate, NSWindowDelegate {
    /// WebKit に返す子 WKWebView (configuration は opener から引き継いだものを使う)
    let webView: WKWebView
    private let window: NSWindow
    private weak var registry: SessionRegistry?

    /// windowFeatures のサイズが無いときの既定サイズ (OAuth ポップアップの一般的な大きさ)
    private static let defaultSize = NSSize(width: 480, height: 640)

    init(configuration: WKWebViewConfiguration, windowFeatures: WKWindowFeatures, registry: SessionRegistry?) {
        let width = windowFeatures.width?.doubleValue ?? Self.defaultSize.width
        let height = windowFeatures.height?.doubleValue ?? Self.defaultSize.height
        let frame = NSRect(x: 0, y: 0, width: width, height: height)

        // configuration をそのまま使うこと (opener / postMessage / window.close を成立させる)。
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.isInspectable = true
        self.webView = webView

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.isReleasedWhenClosed = false
        self.window = window
        self.registry = registry
        super.init()

        webView.uiDelegate = self
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    /// JS の `window.close()` に追従して窓を閉じる。
    func webViewDidClose(_ webView: WKWebView) {
        window.close()
    }

    /// ポップアップ内の入れ子 `window.open` も再帰的に振り分ける。
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let registry else { return nil }
        if windowFeatures.width != nil || windowFeatures.height != nil {
            return registry.openWebPopup(configuration: configuration, windowFeatures: windowFeatures)
        } else {
            return registry.openWebAdopting(configuration: configuration, from: nil)
        }
    }

    /// ユーザの窓クローズ / `window.close()` 双方で registry の保持から外れる。
    func windowWillClose(_ notification: Notification) {
        registry?.releaseWebPopup(self)
    }
}
