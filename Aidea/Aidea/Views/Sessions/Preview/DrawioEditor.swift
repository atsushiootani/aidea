//
//  DrawioEditor.swift
//  Aidea
//

import SwiftUI
import WebKit

/// drawio エディタを WKWebView で埋め込む View。
/// `embed.diagrams.net` を iframe でロードしたラッパ HTML を表示し、
/// postMessage プロトコル経由で XML のロードと保存を行う。
struct DrawioEditor: NSViewRepresentable {
    /// drawio エクスポート形式。`xmlsvg` は SVG (.drawio.svg)、`xml` は純 XML (.drawio)。
    enum ExportFormat: String {
        case xmlsvg
        case xml
    }

    /// 初期ロードする drawio XML (または .drawio.svg の内容)
    let initialXML: String
    /// drawio からの保存時に受け取る形式
    let exportFormat: ExportFormat
    /// 保存時に新しいファイル内容 (SVG 文字列 or XML) を受け取る
    let onSave: (String) -> Void
    /// キャンセル時に呼ばれる
    let onCancel: () -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "drawio")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        context.coordinator.webView = webView

        // iframe で drawio embed をホストするラッパ HTML
        let html = Self.wrapperHTML
        webView.loadHTMLString(html, baseURL: URL(string: "https://embed.diagrams.net/"))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            initialXML: initialXML,
            exportFormat: exportFormat,
            onSave: onSave,
            onCancel: onCancel
        )
    }

    /// drawio embed を iframe でホストするラッパ HTML。
    /// 子 iframe からの postMessage を捕捉して Swift に転送し、
    /// `window.sendToDrawio` グローバル関数で Swift から iframe にメッセージを送る。
    private static let wrapperHTML: String = """
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
                src="https://embed.diagrams.net/?embed=1&ui=dark&spin=1&proto=json&saveAndExit=1&noSaveBtn=0">
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

    /// WKWebView と drawio 間の postMessage を仲介する Coordinator
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let initialXML: String
        let exportFormat: ExportFormat
        let onSave: (String) -> Void
        let onCancel: () -> Void
        weak var webView: WKWebView?

        init(
            initialXML: String,
            exportFormat: ExportFormat,
            onSave: @escaping (String) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.initialXML = initialXML
            self.exportFormat = exportFormat
            self.onSave = onSave
            self.onCancel = onCancel
        }

        /// drawio から届いたメッセージを処理する
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            let event = json["event"] as? String

            switch event {
            case "init":
                // drawio の準備完了 → 初期 XML をロードさせる
                sendLoad(xml: initialXML)
            case "save":
                // ユーザーが drawio で保存ボタンを押した
                if exportFormat == .xml {
                    // 純 XML 形式: save イベントの xml フィールドがそのまま使える
                    if let xml = json["xml"] as? String {
                        onSave(xml)
                    }
                } else {
                    // xmlsvg 形式: export アクションで SVG+XML の data URL を取得する
                    sendExport()
                }
            case "export":
                // エクスポート完了 → data URL から SVG を取り出して onSave に渡す
                if let dataURL = json["data"] as? String,
                   let svg = Self.decodeDataURLToString(dataURL) {
                    onSave(svg)
                }
            case "exit":
                onCancel()
            default:
                break
            }
        }

        /// drawio に load アクションを送る
        private func sendLoad(xml: String) {
            let payload: [String: Any] = [
                "action": "load",
                "xml": xml,
                "autosave": 0
            ]
            sendToDrawio(payload)
        }

        /// drawio に export アクションを送る
        private func sendExport() {
            let payload: [String: Any] = [
                "action": "export",
                "format": exportFormat.rawValue
            ]
            sendToDrawio(payload)
        }

        /// ペイロードを JSON 文字列化して iframe の drawio に postMessage
        private func sendToDrawio(_ payload: [String: Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return
            }
            // JSON 文字列を JS リテラルとして安全にエスケープする
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

        /// data:image/svg+xml;base64,... または data:image/svg+xml;utf8,... を文字列に戻す
        /// 他の View からも使えるよう public 相当 (internal) で公開
        static func decodeDataURLToString(_ dataURL: String) -> String? {
            guard let commaIndex = dataURL.firstIndex(of: ",") else { return nil }
            let meta = String(dataURL[..<commaIndex])
            let payload = String(dataURL[dataURL.index(after: commaIndex)...])
            if meta.contains("base64") {
                guard let data = Data(base64Encoded: payload) else { return nil }
                return String(data: data, encoding: .utf8)
            }
            return payload.removingPercentEncoding ?? payload
        }
    }
}
