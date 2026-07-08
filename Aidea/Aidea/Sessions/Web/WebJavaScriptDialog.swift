//
//  WebJavaScriptDialog.swift
//  Aidea
//

import AppKit
import WebKit

/// ページ内の `window.alert()` / `window.confirm()` / `window.prompt()` を
/// ネイティブの `NSAlert` として表示するヘルパ。
/// 通常タブ (`WebUIDelegate`) とポップアップ窓 (`WebPopupController`) の双方から使う。
///
/// `NSAlert` は WKWebView が乗っているウィンドウのシートとして出し、そのウィンドウだけをブロックする
/// (他ペイン・他窓の操作は妨げない)。ウィンドウが無い稀なケースは `runModal()` にフォールバックする。
///
/// 仕様: docs/specs/tools/web.md#javascript-ダイアログ-alert--confirm--prompt
enum WebJavaScriptDialog {
    /// `window.alert()`。メッセージ + 「OK」。閉じたら `completion()` を一度だけ呼ぶ。
    static func presentAlert(
        message: String,
        webView: WKWebView,
        frame: WKFrameInfo,
        completion: @escaping () -> Void
    ) {
        let alert = makeAlert(message: message, frame: frame)
        alert.addButton(withTitle: "OK")
        present(alert, on: webView.window) { _ in completion() }
    }

    /// `window.confirm()`。メッセージ + 「OK」/「キャンセル」。OK=`true` / キャンセル=`false`。
    static func presentConfirm(
        message: String,
        webView: WKWebView,
        frame: WKFrameInfo,
        completion: @escaping (Bool) -> Void
    ) {
        let alert = makeAlert(message: message, frame: frame)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "キャンセル")
        present(alert, on: webView.window) { response in
            completion(response == .alertFirstButtonReturn)
        }
    }

    /// `window.prompt()`。メッセージ + 入力欄 + 「OK」/「キャンセル」。OK=入力文字列 / キャンセル=`nil`。
    static func presentPrompt(
        message: String,
        defaultText: String?,
        webView: WKWebView,
        frame: WKFrameInfo,
        completion: @escaping (String?) -> Void
    ) {
        let alert = makeAlert(message: message, frame: frame)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "キャンセル")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaultText ?? ""
        alert.accessoryView = input
        // シート表示直後に入力欄へフォーカスを移す
        alert.window.initialFirstResponder = input

        present(alert, on: webView.window) { response in
            completion(response == .alertFirstButtonReturn ? input.stringValue : nil)
        }
    }

    // MARK: - Helpers

    /// 発信元ページのホストをタイトルに、JS メッセージを本文に据えた `NSAlert` を作る
    /// (ブラウザの「<host> says:」慣習に倣う)。
    private static func makeAlert(message: String, frame: WKFrameInfo) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? "このページ"
        alert.informativeText = message
        return alert
    }

    /// `NSAlert` をウィンドウのシートとして表示する。ウィンドウが無ければ `runModal()` にフォールバック。
    private static func present(
        _ alert: NSAlert,
        on window: NSWindow?,
        completion: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        if let window {
            alert.beginSheetModal(for: window) { response in completion(response) }
        } else {
            completion(alert.runModal())
        }
    }
}
