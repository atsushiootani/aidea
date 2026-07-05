//
//  EditableTextView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// NSTextView をラップした編集可能なプレーンテキストビュー。
/// SwiftUI の TextEditor は大きなテキストで重くなるため、NSTextView を直接使う。
struct EditableTextView: NSViewRepresentable {
    @Binding var text: String
    /// NSTextView が生成されたときに呼ばれるコールバック (SessionFocusBridge 報告用)
    var onViewCreated: ((NSView) -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = text
        textView.autoresizingMask = [.width]
        onViewCreated?(textView)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        // IME 変換中は storage に触れない: 未確定文字列は binding に含まれず
        // 「storage ≠ binding」が常に成立するため、無条件同期すると外部要因の
        // 再レンダリング (自動保存の state 更新等) のたびに未確定文字列が破棄される (issue #125)
        if textView.hasMarkedText() { return }
        // エディタ発の変更が binding を往復して戻ってきただけなら同期しない。
        // 連続入力中に古い render の値で storage を巻き戻さないための保護
        if text == context.coordinator.lastEditedText { return }
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    /// NSTextView の編集イベントを SwiftUI Binding に伝搬する Coordinator
    final class Coordinator: NSObject, NSTextViewDelegate {
        let text: Binding<String>
        /// textDidChange で binding に書いた最新値。updateNSView がエディタ発の
        /// 変更を「外部からの変更」と誤認して storage を巻き戻すのを防ぐ
        var lastEditedText: String?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // IME 変換中の未確定文字列は伝搬しない (確定・取消時に改めて呼ばれる)。
            // 未確定分を自動保存に乗せないため (issue #125)
            guard !textView.hasMarkedText() else { return }
            lastEditedText = textView.string
            text.wrappedValue = textView.string
        }
    }
}
