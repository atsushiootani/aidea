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
final class WebSessionState: SessionState, FocusBridgeOwner {
    /// フォーカス契約 C1/C2/C3 を担う非永続ヘルパ (仕様は focus-contract.md)
    let focusBridge = SessionFocusBridge()
    var url: URL = URL(string: "https://www.apple.com")!
    @ObservationIgnored private var cached: WKWebView?
    @ObservationIgnored private var urlObservation: NSKeyValueObservation?

    /// SessionRegistry への弱参照 (クリック時のアクティブ化用)
    weak var registry: SessionRegistry?
    /// この Web セッションの SessionID
    @ObservationIgnored var sessionID: SessionID?

    /// 契約 C1: bridge 経由で webView に firstResponder を移す。
    /// NSView 参照の登録は View 側 (WebSessionView.makeNSView) で行う。
    /// cached が lazy 生成のため pending パターンで自動解消される。
    func didBecomeActive(session: Session) {
        focusBridge.activate()
    }

    /// 契約 C2: bridge 経由で自分配下の firstResponder を解放する。
    /// WKWebView の内部 subview が firstResponder になっているケースも
    /// bridge 側で isDescendant(of:) 判定するため正しく解放される。
    func didResignActive(session: Session) {
        focusBridge.deactivate()
    }

    /// レコメンドモード用の Scene 識別子。Web は URL で分岐しない単一 Scene。
    /// 仕様: docs/specs/sessions/web.md#scene-とレコメンドプロンプト
    func currentScene() -> String? { "web" }

    /// View 側で参照する WKWebView (初回のみ生成)
    var webView: WKWebView {
        if let cached = cached { return cached }
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        webView.load(URLRequest(url: url))
        // WKWebView は mouseDown をオーバーライドできないので、
        // becomeFirstResponder 時にこのセッションをアクティブにする
        let reg = registry
        let sid = sessionID
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak webView] event in
            if let wv = webView,
               let sid = sid,
               let clickedView = event.window?.contentView?.hitTest(event.locationInWindow),
               clickedView.isDescendant(of: wv) {
                reg?.activateSession(sid)
            }
            return event
        }
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
