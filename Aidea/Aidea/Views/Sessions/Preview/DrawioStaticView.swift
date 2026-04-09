//
//  DrawioStaticView.swift
//  Aidea
//

import SwiftUI
import WebKit

/// drawio ファイルを静的に表示する WKWebView ラッパ。
/// NSImage による SVG レンダリングは text 要素が欠落するため、WebKit の本物の
/// SVG レンダラを使って完全なフォント・スタイル再現を行う。
struct DrawioStaticView: NSViewRepresentable {
    let url: URL
    /// 親から reload を促すためのトリガ値 (保存後に変化させる)
    let reloadTick: Int

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.isInspectable = true
        loadDrawio(into: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // URL 変更または保存後の reloadTick 変化で再ロード
        if context.coordinator.lastLoadedURL != url
            || context.coordinator.lastReloadTick != reloadTick {
            loadDrawio(into: nsView)
            context.coordinator.lastLoadedURL = url
            context.coordinator.lastReloadTick = reloadTick
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// .drawio.svg はファイル内容を inline SVG として HTML に埋め込んで表示する。
    /// `<img src="...">` 経由だと WKWebView の baseURL + loadHTMLString の制限で
    /// ローカルファイルが読めないため、SVG 文字列を直接本文に入れる方式を取る。
    private func loadDrawio(into webView: WKWebView) {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".drawio.svg") {
            let svg = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let html = Self.wrapperHTML(inlineSVG: svg)
            webView.loadHTMLString(html, baseURL: nil)
        } else {
            // .drawio (純 XML) は現状プレビュー非対応 (Phase 2)
            let message = """
            <!DOCTYPE html>
            <html><body style="margin:0;padding:20px;background:#1e1e1e;color:#aaa;\
            font-family:-apple-system,sans-serif;font-size:12px;">\
            .drawio (純 XML) のプレビューはまだサポートされていません。<br>\
            Edit ボタンでエディタを開いて確認してください。\
            </body></html>
            """
            webView.loadHTMLString(message, baseURL: nil)
        }
    }

    /// SVG を中央配置・アスペクト維持で表示する HTML ラッパ (inline SVG 埋め込み)
    private static func wrapperHTML(inlineSVG: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                html, body { margin: 0; padding: 0; height: 100%; background: #1e1e1e; }
                body {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    overflow: auto;
                    padding: 16px;
                    box-sizing: border-box;
                }
                svg {
                    max-width: 100%;
                    max-height: 100%;
                    width: auto;
                    height: auto;
                }
            </style>
        </head>
        <body>
        \(inlineSVG)
        </body>
        </html>
        """
    }

    /// 最後にロードした URL / reloadTick を記録する Coordinator
    final class Coordinator {
        var lastLoadedURL: URL?
        var lastReloadTick: Int = -1
    }
}
