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
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        // Coordinator からの更新ループを避けるため、外部から text が変わった場合のみ同期
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

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
