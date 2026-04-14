//
//  GitDiffSessionView.swift
//  Aidea
//

import SwiftUI
import WebKit

/// GitDiff Session の SwiftUI View。全ファイルの diff を WKWebView + diff2html で side-by-side 表示する。
/// Tab キーで Git ツールに戻り、左右キーで水平スクロールする WKWebView
final class GitDiffWebView: WKWebView {
    var onTabPressed: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 48: // Tab
            onTabPressed?()
            return
        case 49: // Space - フォーカスファイルの Viewed チェックボックスをトグル
            evaluateJavaScript("""
                (function() {
                    const centerY = window.innerHeight / 2;
                    const wrappers = document.querySelectorAll('.d2h-file-wrapper');
                    for (const w of wrappers) {
                        const rect = w.getBoundingClientRect();
                        if (rect.top <= centerY && rect.bottom >= centerY) {
                            const cb = w.querySelector('input[type="checkbox"]');
                            if (cb) {
                                cb.click();
                                // 折りたたみでファイルが画面外に行く場合、ヘッダ位置にスクロール
                                setTimeout(function() {
                                    const newRect = w.getBoundingClientRect();
                                    if (newRect.bottom < 0 || newRect.top > window.innerHeight) {
                                        window.scrollBy({ top: newRect.top - 8, behavior: 'smooth' });
                                    }
                                }, 100);
                            }
                            return;
                        }
                    }
                })();
                """, completionHandler: nil)
            return
        case 123: // 左矢印
            evaluateJavaScript("window.scrollBy(-100, 0)", completionHandler: nil)
            return
        case 124: // 右矢印
            evaluateJavaScript("window.scrollBy(100, 0)", completionHandler: nil)
            return
        default:
            break
        }
        super.keyDown(with: event)
    }
}

struct GitDiffSessionView: NSViewRepresentable {
    let session: Session
    let state: GitDiffSessionState

    func makeNSView(context: Context) -> GitDiffWebView {
        let config = WKWebViewConfiguration()
        // スクロール時のフォーカスファイル通知を受け取る
        config.userContentController.add(context.coordinator, name: "focusFile")
        config.userContentController.add(context.coordinator, name: "viewedFile")
        let webView = GitDiffWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        session.focusableView = webView
        context.coordinator.state = state
        state.reload()
        loadDiff(into: webView)
        // Tab で Git ツールにフォーカス移動
        let diffState = state
        webView.onTabPressed = {
            guard let registry = diffState.registry else { return }
            // Git ツールのセッションを探してアクティブ化
            for pane in registry.layout.allPanes {
                for id in pane.tabs where id.tool == .git {
                    registry.activateSession(id)
                    return
                }
            }
        }
        return webView
    }

    func updateNSView(_ nsView: GitDiffWebView, context: Context) {
        if context.coordinator.lastDiff != state.diffOutput {
            loadDiff(into: nsView)
            context.coordinator.lastDiff = state.diffOutput
        }
        // ファイルへのジャンプ指示
        if let file = state.scrollToFile {
            state.scrollToFile = nil
            scrollToFile(file, in: nsView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var lastDiff: String = ""
        weak var state: GitDiffSessionState?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "focusFile", let filePath = message.body as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.state?.focusedFile = filePath
                }
            }
            if message.name == "viewedFile", let info = message.body as? [String: Any],
               let filePath = info["file"] as? String,
               let viewed = info["viewed"] as? Bool {
                DispatchQueue.main.async { [weak self] in
                    if viewed {
                        self?.state?.viewedFiles.insert(filePath)
                    } else {
                        self?.state?.viewedFiles.remove(filePath)
                    }
                }
            }
        }
    }

    /// diff2html のファイルヘッダを検索してスクロールする
    private func scrollToFile(_ filePath: String, in webView: GitDiffWebView) {
        let js = """
        (function() {
            const headers = document.querySelectorAll('.d2h-file-header');
            for (const h of headers) {
                if (h.textContent.includes('\(filePath.replacingOccurrences(of: "'", with: "\\'"))')) {
                    const wrapper = h.closest('.d2h-file-wrapper');
                    const target = wrapper || h;
                    const rect = target.getBoundingClientRect();
                    window.scrollBy({ top: rect.top - 8, behavior: 'smooth' });
                    return true;
                }
            }
            return false;
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func loadDiff(into webView: GitDiffWebView) {
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
                .d2h-file-header { background: #252526; color: #d4d4d4; border-bottom: 1px solid #3c3c3c; padding: 8px 12px; position: sticky; top: 0; z-index: 10; }
                .d2h-file-wrapper { border: 1px solid #3c3c3c; margin-bottom: 8px; }
                .d2h-code-line, .d2h-code-side-line { background: #1e1e1e; border: none; }
                .d2h-code-line-ctn { font-family: 'SF Mono', Menlo, monospace; font-size: 12px; line-height: 1.6; border: none; }
                .d2h-diff-table tr, .d2h-diff-table td, .d2h-diff-tbody tr, .d2h-diff-tbody td { border: none !important; }
                .d2h-code-side-emptyplaceholder, .d2h-emptyplaceholder { background: #252526; border: none !important; }
                .d2h-code-linenumber,
                .d2h-code-side-linenumber { background: #1e1e1e; color: #555; border-right: 1px solid #3c3c3c; border-left: none; border-top: none; border-bottom: none; }
                .d2h-ins { background: rgba(35, 134, 54, 0.2) !important; }
                .d2h-ins .d2h-code-line-ctn { background: transparent !important; }
                .d2h-code-side-linenumber.d2h-ins,
                .d2h-ins.d2h-code-linenumber,
                .d2h-ins.d2h-code-side-linenumber { background: rgba(35, 134, 54, 0.3) !important; color: #858585 !important; }
                ins, .d2h-ins .d2h-code-line-ctn ins { background: rgba(35, 134, 54, 0.65) !important; text-decoration: none !important; color: #fff !important; }
                .d2h-del { background: rgba(218, 54, 51, 0.2) !important; }
                .d2h-del .d2h-code-line-ctn { background: transparent !important; }
                .d2h-code-side-linenumber.d2h-del,
                .d2h-del.d2h-code-linenumber,
                .d2h-del.d2h-code-side-linenumber { background: rgba(218, 54, 51, 0.3) !important; color: #858585 !important; }
                del, .d2h-del .d2h-code-line-ctn del { background: rgba(218, 54, 51, 0.65) !important; text-decoration: none !important; color: #fff !important; }
                .d2h-info { background: #1b3a4b; color: #8db9d5; }
                .d2h-info .d2h-code-line-ctn { background: transparent; }
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
                        fileContentToggle: true,
                    };
                    const diff2htmlUi = new Diff2HtmlUI(targetElement, diffString, configuration);
                    diff2htmlUi.draw();
                    diff2htmlUi.highlightCode();

                    // スクロール時にビューポート中央のファイルを検知して Swift に通知
                    let lastFocusFile = { value: '', el: null };
                    window.addEventListener('scroll', function() {
                        const centerY = window.innerHeight / 2;
                        const wrappers = document.querySelectorAll('.d2h-file-wrapper');
                        let focused = null;
                        for (const w of wrappers) {
                            const rect = w.getBoundingClientRect();
                            if (rect.top <= centerY && rect.bottom >= centerY) {
                                focused = w;
                                break;
                            }
                        }
                        if (!focused) {
                            let minDist = Infinity;
                            for (const w of wrappers) {
                                const rect = w.getBoundingClientRect();
                                const dist = Math.min(Math.abs(rect.top - centerY), Math.abs(rect.bottom - centerY));
                                if (dist < minDist) { minDist = dist; focused = w; }
                            }
                        }
                        if (focused && focused !== lastFocusFile.el) {
                            if (lastFocusFile.el) {
                                const prevHeader = lastFocusFile.el.querySelector('.d2h-file-header');
                                if (prevHeader) { prevHeader.style.background = '#252526'; }
                            }
                            const curHeader = focused.querySelector('.d2h-file-header');
                            if (curHeader) { curHeader.style.background = 'rgb(30, 60, 110)'; }
                            lastFocusFile.el = focused;
                            const header = focused.querySelector('.d2h-file-header');
                            if (header) {
                                const name = header.textContent.trim();
                                if (name !== lastFocusFile.value) {
                                    lastFocusFile.value = name;
                                    window.webkit.messageHandlers.focusFile.postMessage(name);
                                }
                            }
                        }
                    }, { passive: true });

                    // Viewed チェックボックスの変更を Swift に通知
                    document.querySelectorAll('.d2h-file-wrapper input[type="checkbox"]').forEach(function(cb) {
                        cb.addEventListener('change', function() {
                            const wrapper = cb.closest('.d2h-file-wrapper');
                            const header = wrapper ? wrapper.querySelector('.d2h-file-header') : null;
                            if (header) {
                                const name = header.textContent.trim();
                                window.webkit.messageHandlers.viewedFile.postMessage({ file: name, viewed: cb.checked });
                            }
                        });
                    });
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
