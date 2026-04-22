//
//  TabSlotURLDropTarget.swift
//  Aidea
//

import SwiftUI
import AppKit

/// TabSlotView 上に重ねる AppKit ベースのファイル URL ドロップターゲット。
///
/// SwiftUI の `.dropDestination(for: URL.self)` および `.onDrop(of: [.fileURL], …)` は
/// NSOutlineView の `pasteboardWriterForItem` 経由で発生した drag を取りこぼす。
/// (SwiftUI の Transferable / NSItemProvider 経路と AppKit NSPasteboard 経路の橋渡しが
/// ローカルドラッグでは弱いため。)
///
/// このため Filer → TabSlot のドロップはここで AppKit の `registerForDraggedTypes([.fileURL])`
/// により直接受ける。視覚的なハイライトと SessionID 用のドロップは SwiftUI 側で扱う。
struct TabSlotURLDropTarget: NSViewRepresentable {
    let onEnter: () -> Void
    let onExit: () -> Void
    let onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = DropAcceptingView()
        view.onEnter = onEnter
        view.onExit = onExit
        view.onDrop = onDrop
        view.registerForDraggedTypes([.fileURL])
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let v = nsView as? DropAcceptingView else { return }
        v.onEnter = onEnter
        v.onExit = onExit
        v.onDrop = onDrop
    }

    /// hit-test で nil を返してマウスクリック等は下層 SwiftUI に通すが、
    /// `registerForDraggedTypes` は AppKit の dragging dispatcher が別経路で参照するため
    /// drag enter/perform は問題なく届く。
    private final class DropAcceptingView: NSView {
        var onEnter: (() -> Void)?
        var onExit: (() -> Void)?
        var onDrop: (([URL]) -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            onEnter?()
            return .copy
        }

        override func draggingExited(_ sender: NSDraggingInfo?) {
            onExit?()
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            onExit?()
            let pb = sender.draggingPasteboard
            let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
            guard let urls = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
                  !urls.isEmpty else {
                return false
            }
            onDrop?(urls)
            return true
        }

        override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }
    }
}
