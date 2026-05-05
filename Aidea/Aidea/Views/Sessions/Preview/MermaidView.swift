//
//  MermaidView.swift
//  Aidea

import SwiftUI
import WebKit

/// Mermaid 記法のコードブロックを図として表示する SwiftUI View。
/// CDN (jsdelivr) から Mermaid.js を読み込むためネットワーク接続が必要。
/// NSViewRepresentable 採用理由: WKWebView をホストするため。
struct MermaidView: View {
    let diagram: String
    @State private var contentHeight: CGFloat = 160

    var body: some View {
        _MermaidWebView(diagram: diagram, contentHeight: $contentHeight)
            .frame(height: contentHeight)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.12))
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct _MermaidWebView: NSViewRepresentable {
    let diagram: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(
            MermaidMessageProxy(context.coordinator), name: "height"
        )
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.isInspectable = true
        context.coordinator.heightBinding = $contentHeight
        context.coordinator.load(diagram, into: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.heightBinding = $contentHeight
        guard context.coordinator.lastDiagram != diagram else { return }
        context.coordinator.load(diagram, into: nsView)
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "height")
    }

    final class Coordinator: NSObject {
        var lastDiagram = ""
        var heightBinding: Binding<CGFloat>?

        func reportHeight(_ value: NSNumber) {
            DispatchQueue.main.async { [weak self] in
                self?.heightBinding?.wrappedValue = max(CGFloat(value.doubleValue) + 16, 60)
            }
        }

        func load(_ diagram: String, into webView: WKWebView) {
            lastDiagram = diagram
            webView.loadHTMLString(html(for: diagram), baseURL: nil)
        }

        private func html(for diagram: String) -> String {
            let safe = diagram
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            return """
            <!DOCTYPE html><html>
            <head>
            <meta charset="utf-8">
            <style>
              html,body{margin:0;padding:8px;background:transparent;}
              #graph{display:flex;justify-content:center;}
              #graph svg{max-width:100%;height:auto;}
              #error{color:#e06c75;font:12px/1.4 monospace;white-space:pre-wrap;padding:8px;}
            </style>
            </head>
            <body>
              <div id="graph"></div>
              <div id="error"></div>
              <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
              <script>
                mermaid.initialize({startOnLoad:false,theme:'neutral'});
                mermaid.render('mermaid-diagram',`\(safe)`).then(({svg})=>{
                  document.getElementById('graph').innerHTML=svg;
                  window.webkit.messageHandlers.height.postMessage(document.documentElement.scrollHeight);
                }).catch(err=>{
                  document.getElementById('error').textContent='Mermaid parse error: '+err.message;
                  window.webkit.messageHandlers.height.postMessage(document.documentElement.scrollHeight);
                });
              </script>
            </body>
            </html>
            """
        }
    }
}

/// WKUserContentController → Coordinator の retain cycle を防ぐ weak proxy
private final class MermaidMessageProxy: NSObject, WKScriptMessageHandler {
    weak var coordinator: _MermaidWebView.Coordinator?
    init(_ coordinator: _MermaidWebView.Coordinator) { self.coordinator = coordinator }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let n = message.body as? NSNumber else { return }
        coordinator?.reportHeight(n)
    }
}
