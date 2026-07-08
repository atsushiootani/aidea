//
//  WebUIDelegate.swift
//  Aidea
//

import AppKit
import WebKit

/// WebSessionState の WKWebView に紐づく `WKUIDelegate`。
/// `window.open()` / `target="_blank"` を windowFeatures のサイズ指定有無で振り分ける。
///
/// - サイズ指定あり (`window.open(url, name, "width=..,height=..")`) → フローティングポップアップ窓
/// - サイズ指定なし (`target="_blank"` / `window.open(url)`) → 呼び出し元と同じペインの右隣に新規 Web タブ
///
/// 仕様: docs/specs/tools/web.md#windowopen--targetblank-のルーティング-adr-0035
/// 判断: [ADR 0035](../../../docs/decisions/0035-web-window-open-tab-and-popup.md)
final class WebUIDelegate: NSObject, WKUIDelegate {
    /// 出し先の生成を委譲する SessionRegistry
    weak var registry: SessionRegistry?
    /// この WebView を保持する WebSessionState (新規タブの配置基準 = opener)
    weak var owner: WebSessionState?

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let registry else { return nil }
        // WebKit から渡された configuration をそのまま使うこと (opener / postMessage / window.close を成立させる)。
        // 子 WKWebView を自前で load してはならない (WebKit が navigationAction を自動ロードする)。
        if windowFeatures.width != nil || windowFeatures.height != nil {
            return registry.openWebPopup(configuration: configuration, windowFeatures: windowFeatures)
        } else {
            return registry.openWebAdopting(configuration: configuration, from: owner?.sessionID)
        }
    }

    // MARK: - JavaScript ダイアログ (alert / confirm / prompt)
    // 未実装だと WebKit がダイアログを握り潰す。表示ロジックは WebJavaScriptDialog に集約する。
    // 仕様: docs/specs/tools/web.md#javascript-ダイアログ-alert--confirm--prompt

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        WebJavaScriptDialog.presentAlert(message: message, webView: webView, frame: frame, completion: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        WebJavaScriptDialog.presentConfirm(message: message, webView: webView, frame: frame, completion: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        WebJavaScriptDialog.presentPrompt(message: prompt, defaultText: defaultText, webView: webView, frame: frame, completion: completionHandler)
    }
}
