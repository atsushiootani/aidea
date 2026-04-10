//
//  DrawioStaticView.swift
//  Aidea
//

import SwiftUI
import WebKit

/// drawio ファイルを静的に表示する WKWebView ラッパ。
///
/// - `.drawio.svg`: SVG を inline で HTML に埋め込んで WebKit に描画させる
/// - `.drawio` (純 XML): drawio embed を `chrome=0` でロードし、postMessage 経由で XML をロード
struct DrawioStaticView: NSViewRepresentable {
    let url: URL
    /// 親から reload を促すためのトリガ値 (保存後に変化させる)
    let reloadTick: Int
    /// 値が変化すると drawio に xmlsvg export を要求し、結果を `onConvert` に渡す
    var convertTick: Int = 0
    /// xmlsvg export 完了時のコールバック (生成された SVG 文字列)
    var onConvert: ((String) -> Void)? = nil
    /// WKWebView が生成されたときに呼ばれるコールバック (focusableView 報告用)
    var onViewCreated: ((NSView) -> Void)? = nil

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // .drawio (純 XML) のとき drawio からのメッセージを受信する用
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "drawio")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.isInspectable = true
        context.coordinator.webView = webView

        loadDrawio(into: webView, coordinator: context.coordinator)
        onViewCreated?(webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 最新のコールバックを Coordinator にセット
        context.coordinator.onConvert = onConvert

        if context.coordinator.lastLoadedURL != url
            || context.coordinator.lastReloadTick != reloadTick {
            loadDrawio(into: nsView, coordinator: context.coordinator)
            context.coordinator.lastLoadedURL = url
            context.coordinator.lastReloadTick = reloadTick
        }
        // convertTick が増えたら drawio に xmlsvg export を要求する
        if context.coordinator.lastConvertTick != convertTick {
            context.coordinator.lastConvertTick = convertTick
            if convertTick > 0 {
                context.coordinator.requestExport()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// ファイル種別に応じた読み込みパスを実行する
    private func loadDrawio(into webView: WKWebView, coordinator: Coordinator) {
        let name = url.lastPathComponent.lowercased()
        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

        if name.hasSuffix(".drawio.svg") {
            // SVG はそのまま inline で表示できる
            let html = Self.svgWrapperHTML(inlineSVG: contents)
            coordinator.pendingXML = nil
            webView.loadHTMLString(html, baseURL: nil)
        } else {
            // 純 XML は drawio embed (chrome=0) を読み込んで postMessage でロード
            coordinator.pendingXML = contents
            let html = Self.embedViewerHTML
            webView.loadHTMLString(html, baseURL: URL(string: "https://embed.diagrams.net/"))
        }
    }

    // MARK: - HTML templates

    /// SVG 文字列を中央配置で表示する HTML
    private static func svgWrapperHTML(inlineSVG: String) -> String {
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

    /// drawio embed (編集 UI なし) を iframe でホストする HTML。
    /// `chrome=0` で編集ツールバーを非表示にし、純粋な viewer として動作させる。
    private static let embedViewerHTML: String = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            html, body { margin: 0; padding: 0; height: 100%; background: #1e1e1e; }
            iframe { width: 100%; height: 100%; border: 0; display: block; }
        </style>
    </head>
    <body>
        <iframe id="drawioFrame"
                src="https://embed.diagrams.net/?embed=1&ui=dark&proto=json&chrome=0&nav=1">
        </iframe>
        <script>
            const frame = document.getElementById("drawioFrame");
            window.addEventListener("message", function(e) {
                if (e.source !== frame.contentWindow) return;
                if (typeof e.data === "string") {
                    window.webkit.messageHandlers.drawio.postMessage(e.data);
                }
            });
            window.sendToDrawio = function(jsonString) {
                frame.contentWindow.postMessage(jsonString, "*");
            };
        </script>
    </body>
    </html>
    """

    /// .drawio (純 XML) ロード時の状態を保持する Coordinator
    final class Coordinator: NSObject, WKScriptMessageHandler {
        var lastLoadedURL: URL?
        var lastReloadTick: Int = -1
        var lastConvertTick: Int = 0
        weak var webView: WKWebView?
        /// embed viewer 経由でロードする XML (init イベント受信時に送信する)
        var pendingXML: String?
        /// drawio が init を返したか
        var isReady: Bool = false
        /// xmlsvg export の結果を渡すコールバック
        var onConvert: ((String) -> Void)?
        /// init 前に export 要求を受けた場合に保留する
        var pendingExportRequest: Bool = false

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let event = json["event"] as? String else {
                return
            }
            switch event {
            case "init":
                isReady = true
                if let xml = pendingXML {
                    sendLoad(xml: xml)
                }
                if pendingExportRequest {
                    pendingExportRequest = false
                    sendExport()
                }
            case "export":
                if let dataURL = json["data"] as? String,
                   let svg = DrawioEditor.Coordinator.decodeDataURLToString(dataURL) {
                    onConvert?(svg)
                }
            default:
                break
            }
        }

        /// 親から呼ばれて xmlsvg export を要求する
        func requestExport() {
            if isReady {
                sendExport()
            } else {
                // drawio がまだ init を返していない場合は保留しておく
                pendingExportRequest = true
            }
        }

        /// drawio embed に load アクションを送る
        private func sendLoad(xml: String) {
            send(payload: ["action": "load", "xml": xml, "autosave": 0])
        }

        /// drawio embed に export アクションを送る (xmlsvg 形式)
        private func sendExport() {
            send(payload: ["action": "export", "format": "xmlsvg"])
        }

        /// JSON ペイロードを iframe の drawio に postMessage で送信する
        private func send(payload: [String: Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let jsonString = String(data: data, encoding: .utf8) else { return }
            let escaped = jsonString
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            let js = "window.sendToDrawio('\(escaped)');"
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(js)
            }
        }
    }
}
