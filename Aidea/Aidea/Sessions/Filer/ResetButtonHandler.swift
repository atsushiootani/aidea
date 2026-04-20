//
//  ResetButtonHandler.swift
//  Aidea
//

import AppKit

/// `ExcludeRulesDialog` の「デフォルトに戻す」ボタン用 target/action を引き受ける薄いハンドラ。
/// ボタンの target にクロージャを渡せないため小クラスで包む。
final class ResetButtonHandler: NSObject {
    private let textView: NSTextView
    private let defaults: [String]

    init(textView: NSTextView, defaults: [String]) {
        self.textView = textView
        self.defaults = defaults
    }

    /// テキストビューの内容をデフォルトパターンで上書きする
    @objc func reset() {
        textView.string = defaults.joined(separator: "\n")
    }
}
