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
    /// 戻る/進むボタンの有効状態 (WKWebView の同名プロパティに KVO 追従)
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    @ObservationIgnored private var cached: WKWebView?
    @ObservationIgnored private var urlObservation: NSKeyValueObservation?
    @ObservationIgnored private var backObservation: NSKeyValueObservation?
    @ObservationIgnored private var forwardObservation: NSKeyValueObservation?

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
        // ナビゲーションツールバーの戻る/進むボタンの有効状態に追従する
        backObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
            let value = webView.canGoBack
            Task { @MainActor in
                self?.canGoBack = value
            }
        }
        forwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
            let value = webView.canGoForward
            Task { @MainActor in
                self?.canGoForward = value
            }
        }
        cached = webView
        return webView
    }

    /// URL 欄の入力文字列を解釈してロードする (仕様: docs/specs/tools/web.md#url-欄の入力解釈)。
    /// scheme なしは `https://` を補完し、URL として解釈できない入力は無視する。
    func loadURLString(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate), url.host() != nil else { return }
        webView.load(URLRequest(url: url))
    }

    /// ページ内検索 (WKWebView の find API)。一致したら completion(true) を返す。
    /// 大文字小文字は無視し、末尾で先頭へ折り返す。forward=false で後方検索。
    func find(_ text: String, forward: Bool = true, completion: @escaping (Bool) -> Void) {
        guard !text.isEmpty else { completion(true); return }
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.caseSensitive = false
        config.wraps = true
        webView.find(text, configuration: config) { result in
            completion(result.matchFound)
        }
    }
}
