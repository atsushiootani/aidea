//
//  GitDiffSessionView.swift
//  Aidea
//

import SwiftUI
import WebKit

/// GitDiff Session の SwiftUI View。WKWebView + diff2html で side-by-side 表示する。
struct GitDiffSessionView: NSViewRepresentable {
    let session: Session
    let state: GitDiffSessionState

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        session.focusableView = webView
        state.reload()
        loadDiff(into: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // diffOutput が変わったらリロード (discard 後など)
        if context.coordinator.lastDiff != state.diffOutput {
            loadDiff(into: nsView)
            context.coordinator.lastDiff = state.diffOutput
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastDiff: String = ""
    }

    private func loadDiff(into webView: WKWebView) {
        let base64 = Data(state.diffOutput.utf8).base64EncodedString()
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/diff2html/bundles/css/diff2html.min.css" />
            <script src="https://cdn.jsdelivr.net/npm/diff2html/bundles/js/diff2html-ui.min.js"></script>
            <style>
                body { margin: 0; background: #1e1e1e; color: #d4d4d4; font-family: -apple-system, sans-serif; }
                .d2h-wrapper { font-size: 13px; }
                .d2h-file-header { background: #252526; color: #d4d4d4; border-bottom: 1px solid #3c3c3c; padding: 8px 12px; }
                .d2h-file-wrapper { border: 1px solid #3c3c3c; margin-bottom: 0; }
                .d2h-code-line, .d2h-code-side-line { background: #1e1e1e; border: none; }
                .d2h-code-line-ctn { font-family: 'SF Mono', Menlo, monospace; font-size: 12px; line-height: 1.6; border: none; }
                /* 罫線をすべて除去 */
                .d2h-diff-table tr, .d2h-diff-table td, .d2h-diff-tbody tr, .d2h-diff-tbody td { border: none !important; }
                .d2h-code-side-emptyplaceholder, .d2h-emptyplaceholder { background: #252526; border: none !important; }
                /* 行番号: 変更なし行は背景と同化 */
                .d2h-code-linenumber,
                .d2h-code-side-linenumber { background: #1e1e1e; color: #555; border-right: 1px solid #3c3c3c; border-left: none; border-top: none; border-bottom: none; }
                /* 追加行 */
                .d2h-ins { background: rgba(35, 134, 54, 0.2) !important; }
                .d2h-ins .d2h-code-line-ctn { background: transparent !important; }
                .d2h-code-side-linenumber.d2h-ins,
                .d2h-ins.d2h-code-linenumber,
                .d2h-ins.d2h-code-side-linenumber { background: rgba(35, 134, 54, 0.3) !important; color: #858585 !important; }
                ins, .d2h-ins .d2h-code-line-ctn ins { background: rgba(35, 134, 54, 0.65) !important; text-decoration: none !important; color: #fff !important; }
                /* 削除行 */
                .d2h-del { background: rgba(218, 54, 51, 0.2) !important; }
                .d2h-del .d2h-code-line-ctn { background: transparent !important; }
                .d2h-code-side-linenumber.d2h-del,
                .d2h-del.d2h-code-linenumber,
                .d2h-del.d2h-code-side-linenumber { background: rgba(218, 54, 51, 0.3) !important; color: #858585 !important; }
                del, .d2h-del .d2h-code-line-ctn del { background: rgba(218, 54, 51, 0.65) !important; text-decoration: none !important; color: #fff !important; }
                /* 情報行 */
                .d2h-info { background: #1b3a4b; color: #8db9d5; }
                .d2h-info .d2h-code-line-ctn { background: transparent; }
                /* スクロール */
                ::-webkit-scrollbar { width: 8px; height: 8px; }
                ::-webkit-scrollbar-track { background: #1e1e1e; }
                ::-webkit-scrollbar-thumb { background: #424242; border-radius: 4px; }
                ::-webkit-scrollbar-thumb:hover { background: #555; }
                .empty-message { padding: 40px; text-align: center; color: #888; font-size: 14px; }
            </style>
        </head>
        <body>
            <div id="diff"></div>
            <script>
                const diffString = new TextDecoder().decode(Uint8Array.from(atob('\(base64)'), c => c.charCodeAt(0)));
                if (diffString.trim().length === 0) {
                    document.getElementById('diff').innerHTML = '<div class="empty-message">差分がありません</div>';
                } else {
                    const targetElement = document.getElementById('diff');
                    const configuration = {
                        drawFileList: false,
                        outputFormat: 'side-by-side',
                        matching: 'lines',
                        highlight: true,
                    };
                    const diff2htmlUi = new Diff2HtmlUI(targetElement, diffString, configuration);
                    diff2htmlUi.draw();
                    diff2htmlUi.highlightCode();
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
