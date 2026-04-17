//
//  PersistentTerminalView.swift
//  Aidea
//

import AppKit
import SwiftTerm

/// SwiftTerm の LocalProcessTerminalView を拡張して、
/// ペイン間移動時の detach/reattach による一時的な frame = 0 状態で
/// バッファがクリアされるのを防ぐ。
///
/// SwiftUI の ZStack から別の ZStack に NSView が移動する間、一瞬だけ
/// superview が nil になる or bounds が 0 になる。このとき SwiftTerm は
/// レイアウトを走らせてターミナルの cols/rows を 0 に resize し、
/// その結果 Main バッファの可視行をクリアしてしまう。
///
/// 極小 bounds ではレイアウトをスキップすることでこの挙動を回避する。
final class PersistentTerminalView: LocalProcessTerminalView {
    /// レイアウトをスキップする閾値 (ポイント)
    private static let minimumLayoutSize: CGFloat = 10

    /// クリック時にこのセッションをアクティブにするためのコールバック
    var onInteraction: (() -> Void)?

    override func layout() {
        if bounds.width < Self.minimumLayoutSize || bounds.height < Self.minimumLayoutSize {
            return
        }
        super.layout()
    }

    /// フレームが極小になるタイミング (detach 中など) で SwiftTerm に小さな
    /// フレームが伝わると cols/rows が 0 にリサイズされてバッファが消える。
    /// 小さなフレームは無視して前回サイズを維持する。
    override func setFrameSize(_ newSize: NSSize) {
        if newSize.width < Self.minimumLayoutSize || newSize.height < Self.minimumLayoutSize {
            return
        }
        super.setFrameSize(newSize)
    }

    override func setBoundsSize(_ newSize: NSSize) {
        if newSize.width < Self.minimumLayoutSize || newSize.height < Self.minimumLayoutSize {
            return
        }
        super.setBoundsSize(newSize)
    }

    // MARK: - URL 誤発火防止 (Issue #54)
    //
    // SwiftTerm は NSTrackingArea (.activeAlways) を登録し、mouseMoved で
    // URL を検知してブラウザを開く。updateTrackingAreas() は non-open で
    // override できないため、NSEvent ローカルモニターで mouseMoved を
    // 握りつぶして URL 誤発火を防止する。

    private var linkGuard: TerminalLinkGuard?
    private var mouseMoveMonitor: Any?
    private var scrollMonitor: Any?
    private var middleClickMonitor: Any?
    /// Claude CLI のトランスクリプトモードかどうかを最下行のテキストから判定する
    private var isTranscriptMode: Bool {
        guard terminal.isCurrentBufferAlternate else { return false }
        let lastRow = terminal.rows - 1
        guard let line = terminal.getLine(row: lastRow) else { return false }
        let text = line.translateToString(trimRight: true)
        return text.contains("transcript")
    }

    /// terminalDelegate をプロキシに差し替え、mouseMoved を抑制して URL 誤発火を防ぐ。
    /// isClaudeSession = true の場合、スクロール変換とホイールクリックも有効にする。
    func installLinkGuard(isClaudeSession: Bool = false) {
        // delegate プロキシ: requestOpenLink を Cmd+Click のみに制限
        let guard_ = TerminalLinkGuard(original: self)
        linkGuard = guard_
        terminalDelegate = guard_

        // mouseMoved モニター: この TerminalView 宛の mouseMoved を握りつぶす
        mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { [weak self] event in
            guard let self else { return event }
            if let hitView = event.window?.contentView?.hitTest(event.locationInWindow),
               hitView === self || hitView.isDescendant(of: self) {
                return nil
            }
            return event
        }

        // Claude セッション専用: スクロール変換とホイールクリック
        guard isClaudeSession else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  self.terminal.isCurrentBufferAlternate,
                  event.deltaY != 0,
                  let hitView = event.window?.contentView?.hitTest(event.locationInWindow),
                  hitView === self || hitView.isDescendant(of: self) else {
                return event
            }
            // トランスクリプトモードの時だけ Ctrl+U/D を送信
            guard self.isTranscriptMode else { return event }
            self.send([event.deltaY > 0 ? 0x15 : 0x04])
            return nil
        }

        // ホイールクリック（ミドルクリック）→ Ctrl+O を送信
        middleClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self,
                  event.buttonNumber == 2,
                  let hitView = event.window?.contentView?.hitTest(event.locationInWindow),
                  hitView === self || hitView.isDescendant(of: self) else {
                return event
            }
            self.send([0x0f]) // Ctrl+O
            return nil
        }
    }

    deinit {
        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = middleClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

/// SwiftTerm の terminalDelegate をラップし、
/// Cmd+Click 以外での URL オープンを抑制するプロキシ。
final class TerminalLinkGuard: NSObject, TerminalViewDelegate {
    private weak var original: (any TerminalViewDelegate)?

    init(original: any TerminalViewDelegate) {
        self.original = original
    }

    func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {
        guard NSEvent.modifierFlags.contains(.command),
              let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        original?.send(source: source, data: data)
    }

    func scrolled(source: TerminalView, position: Double) {
        original?.scrolled(source: source, position: position)
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        original?.sizeChanged(source: source, newCols: newCols, newRows: newRows)
    }

    func setTerminalTitle(source: TerminalView, title: String) {
        original?.setTerminalTitle(source: source, title: title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        original?.hostCurrentDirectoryUpdate(source: source, directory: directory)
    }

    func bell(source: TerminalView) {
        original?.bell(source: source)
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        original?.clipboardCopy(source: source, content: content)
    }

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
        original?.iTermContent(source: source, content: content)
    }

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        original?.rangeChanged(source: source, startY: startY, endY: endY)
    }
}
