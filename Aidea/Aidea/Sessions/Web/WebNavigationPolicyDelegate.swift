//
//  WebNavigationPolicyDelegate.swift
//  Aidea
//

import AppKit
import WebKit

/// Web タブ / ポップアップ窓の WKWebView に付ける `WKNavigationDelegate`。
/// scheme 許可リスト (`ExternalURLPolicy`) に従い、WebKit が読み込めない scheme
/// (`vscode:` / `smb:` 等) を LaunchServices へ黙って渡させない (issue #294)。
/// - http / https / about / blob / data: そのまま読み込む
/// - それ以外: メインフレームでユーザがリンクを押したときだけ確認後に外部アプリで開き、他は捨てる
///
/// 仕様: docs/specs/tools/web.md#外部-scheme-のナビゲーション
final class WebNavigationPolicyDelegate: NSObject, WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        let userInitiated = isMainFrame && navigationAction.navigationType == .linkActivated
        switch ExternalURLPolicy.webNavigation(url, userInitiated: userInitiated) {
        case .allow:
            decisionHandler(.allow)
        case .confirmExternal:
            decisionHandler(.cancel)
            ExternalURLConfirmation.confirmAndOpen(url, in: webView.window)
        case .reject:
            NSLog("[Aidea] Web: 外部 scheme へのナビゲーションを拒否: \(url.scheme ?? "")")
            decisionHandler(.cancel)
        }
    }
}
