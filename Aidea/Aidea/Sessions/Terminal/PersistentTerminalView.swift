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

    /// クリック判定の許容距離 (mouseDown→mouseUp 間の移動量、4 pt)。
    /// これ以下かつドラッグ未発生のときのみ「単純クリック」と判定する。
    /// 仕様: docs/specs/tools/terminal.md#クリック判定-tap-vs-drag
    private static let tapThreshold: CGFloat = 4

    /// クリック時にこのセッションをアクティブにするためのコールバック
    var onInteraction: (() -> Void)?

    /// PTY からの出力でターミナルバッファが更新された時に呼ばれるコールバック (issue #45)。
    /// Claude セッションで `isBusy` デバウンス判定に利用する。TerminalLinkGuard.rangeChanged
    /// が経由して呼び出す (installLinkGuard 済みのセッションのみ発火する)。
    var onTerminalOutput: (() -> Void)?

    /// ユーザのキー入力が PTY に送出される直前に呼ばれるコールバック (issue #45)。
    /// `TerminalLinkGuard.send` が経由して呼び出す。Claude セッションで「ターミナル上で
    /// 直接 Enter を打った = プロンプト送信」を検知して `markBusy` を発火させる用途。
    /// `Aidea.sendMessage` 経由の送信でもここを通るが、markBusy が重複しても害はない。
    var onKeySend: ((ArraySlice<UInt8>) -> Void)?

    /// 直前の mouseDown→mouseUp が「単純クリック」だったかを示すフラグ (issue #71)。
    /// `TerminalLinkGuard.requestOpenLink` がこれを参照して、ドラッグ選択中の偶発的な URL
    /// 起動を抑止する。SwiftTerm の `mouseUp` が super を経由して `requestOpenLink` を呼ぶ
    /// 直前にセットし、`mouseUp` 終了時に false に戻す。
    fileprivate(set) var lastInteractionWasTap = false

    /// 相対パス解決の起点 (`workspace.projectRoot`) を引くための弱参照 (Session 側で注入)。
    /// ファイルパスのクリック起動時に projectRoot 起点で絶対化するために使う。
    weak var workspace: WorkspaceState?

    /// クリック起動でファイルを Preview に開くためのレジストリ (Session 側で注入)。
    weak var sessionRegistry: SessionRegistry?

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

    // MARK: - URL 誤発火防止 (Issue #54) / クリック起動 (Issue #71)
    //
    // SwiftTerm は NSTrackingArea (.activeAlways) を登録し、mouseMoved で
    // URL を検知してブラウザを開く。updateTrackingAreas() は non-open で
    // override できないため、NSEvent ローカルモニターで mouseMoved を
    // 握りつぶして URL 誤発火を防止する。同じ mouseMoved モニターでホバー位置の
    // クリックターゲット判定も行い、URL/ファイルパス上では `pointingHand` を
    // 設定する。

    private var linkGuard: TerminalLinkGuard?
    private var mouseMoveMonitor: Any?
    private var mouseDownMonitor: Any?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?
    private var scrollMonitor: Any?
    private var middleClickMonitor: Any?
    /// mouseDown 時のウィンドウ座標 (tap vs drag 判定用)
    private var mouseDownLocation: CGPoint?
    /// mouseDown 以降に有意な mouseDragged が発生したか
    private var didDragSinceMouseDown = false
    /// 現在ホバーカーソルが pointingHand 表示中か (毎 frame で set し直さないため)
    private var isShowingPointingHand = false
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
        // delegate プロキシ: requestOpenLink を tap 判定に従って制限
        let guard_ = TerminalLinkGuard(original: self)
        linkGuard = guard_
        terminalDelegate = guard_

        // SwiftTerm の link 機能を Cmd 不要のホバーモードに切り替える (issue #71)。
        // .hoverWithModifier (既定) だと Cmd 押下中のみリンク判定されるため、単純クリックで
        // 開く挙動を実現するために .hover に変更する。
        linkHighlightMode = .hover

        // mouseMoved モニター: この TerminalView 宛の mouseMoved を握りつぶしつつ、
        // ホバー位置がクリックターゲット (URL / 実在するファイルパス) なら
        // カーソルを `pointingHand` に変える (issue #71)。
        mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { [weak self] event in
            guard let self else { return event }
            if let hitView = event.window?.contentView?.hitTest(event.locationInWindow),
               hitView === self || hitView.isDescendant(of: self) {
                self.updateHoverCursor(at: event.locationInWindow)
                return nil
            }
            self.resetHoverCursorIfNeeded()
            return event
        }

        // mouseDown/Dragged/Up モニター: tap vs drag を判定し `lastInteractionWasTap` に反映する。
        // SwiftTerm の MacTerminalView.mouseDown/mouseUp/mouseDragged は non-open のため
        // override できない。NSEvent local monitor で hitTest 越しに判定する。
        // event は常に return して SwiftTerm に流し、内部のテキスト選択や linkForClick は
        // 既存どおりに動かす。`lastInteractionWasTap` が true の間に super.mouseUp が呼ばれ、
        // その内部の `requestOpenLink` が `TerminalLinkGuard.requestOpenLink` 経由で起動可否を
        // 判定する。
        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self,
                  let hitView = event.window?.contentView?.hitTest(event.locationInWindow),
                  hitView === self || hitView.isDescendant(of: self) else {
                return event
            }
            self.mouseDownLocation = event.locationInWindow
            self.didDragSinceMouseDown = false
            self.lastInteractionWasTap = false
            return event
        }
        mouseDraggedMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            guard let self,
                  let start = self.mouseDownLocation,
                  !self.didDragSinceMouseDown else { return event }
            let dx = event.locationInWindow.x - start.x
            let dy = event.locationInWindow.y - start.y
            if hypot(dx, dy) > Self.tapThreshold {
                self.didDragSinceMouseDown = true
            }
            return event
        }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self else { return event }
            // hitView が自 View 配下、かつ mouseDown を観測していた場合のみ tap 判定を立てる。
            // hitView が外れた場合 (drag-out して別 View で離した) は tap 扱いしない。
            let isTap: Bool
            if let start = self.mouseDownLocation,
               let hitView = event.window?.contentView?.hitTest(event.locationInWindow),
               hitView === self || hitView.isDescendant(of: self) {
                let dx = event.locationInWindow.x - start.x
                let dy = event.locationInWindow.y - start.y
                isTap = !self.didDragSinceMouseDown && hypot(dx, dy) <= Self.tapThreshold
            } else {
                isTap = false
            }
            self.lastInteractionWasTap = isTap
            // この後 SwiftTerm.mouseUp が dispatch され、内部で linkForClick → requestOpenLink
            // が呼ばれる。フラグを次の run loop でリセットする (URL 起動判定が同期的に走るため)。
            // パスのクリック起動も同じく次の run loop で実行する (SwiftTerm の mouseUp 処理完了後)。
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if isTap {
                    self.handlePathClickIfNeeded(at: event.locationInWindow)
                }
                self.lastInteractionWasTap = false
                self.mouseDownLocation = nil
                self.didDragSinceMouseDown = false
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
        for monitor in [mouseMoveMonitor, mouseDownMonitor, mouseDraggedMonitor, mouseUpMonitor, scrollMonitor, middleClickMonitor] {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    // MARK: - Path click activation (issue #71)

    /// クリック位置にあるファイルパス候補を検出し、Preview を開くかパス選択メニューを表示する。
    /// 直接解決できない相対パスはプロジェクト内検索フォールバックで補完する。
    /// projectRoot / sessionRegistry が未設定 (Session 側で未注入) の場合は何もしない。
    /// Preview はターミナルと同じペインの右隣タブに開く (`openPreviewAsSibling`)。
    private func handlePathClickIfNeeded(at locationInWindow: CGPoint) {
        guard let registry = sessionRegistry,
              let pos = cellPosition(at: locationInWindow),
              let line = terminal.getLine(row: pos.bufferRow)?
                  .translateToString(trimRight: false)
        else { return }
        switch TerminalPathResolver.matchWithFallback(
            in: line,
            at: pos.col,
            projectRoot: workspace?.projectRoot
        ) {
        case .none:
            break
        case .single(let match):
            registry.openPreviewAsSibling(for: match.absoluteURL, title: match.displayPath)
        case .multiple(let matches):
            showPathSelectionMenu(matches: matches, at: locationInWindow)
        }
    }

    /// 複数候補が存在するときにクリック位置近傍に NSMenu を表示してユーザに選択させる。
    private func showPathSelectionMenu(matches: [TerminalPathMatch], at locationInWindow: CGPoint) {
        let menu = NSMenu()
        for match in matches {
            let item = NSMenuItem(
                title: match.displayPath,
                action: #selector(pathMenuItemSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = match.absoluteURL
            menu.addItem(item)
        }
        let pointInView = convert(locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: pointInView, in: self)
    }

    @objc private func pathMenuItemSelected(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL,
              let registry = sessionRegistry else { return }
        registry.openPreviewAsSibling(for: url, title: sender.title)
    }

    // MARK: - Hover cursor (issue #71)

    /// ホバー位置がクリックターゲット (URL / 実在するファイルパス) なら指マークに切り替える。
    private func updateHoverCursor(at locationInWindow: CGPoint) {
        if isHoveringClickable(at: locationInWindow) {
            if !isShowingPointingHand {
                NSCursor.pointingHand.set()
                isShowingPointingHand = true
            }
        } else {
            resetHoverCursorIfNeeded()
        }
    }

    /// ホバーが View 外に出たり、ターゲット外に移動したりしたときに通常カーソルへ戻す。
    private func resetHoverCursorIfNeeded() {
        if isShowingPointingHand {
            NSCursor.iBeam.set()
            isShowingPointingHand = false
        }
    }

    /// 指定座標がクリック可能なターゲット (URL / ファイルパス / フォールバック候補) の上にあるか判定する。
    private func isHoveringClickable(at locationInWindow: CGPoint) -> Bool {
        guard let pos = cellPosition(at: locationInWindow) else { return false }
        // URL/OSC 8 リンク判定: SwiftTerm の `link(at:mode:)` を活用
        let bufferPos = Position(col: pos.col, row: pos.bufferRow)
        if terminal.link(at: .buffer(bufferPos), mode: .explicitAndImplicit) != nil {
            return true
        }
        // ファイルパス判定: フォールバック検索を含む matchWithFallback で実在確認まで行う
        guard let line = terminal.getLine(row: pos.bufferRow)?
                  .translateToString(trimRight: false) else {
            return false
        }
        if case .none = TerminalPathResolver.matchWithFallback(
            in: line,
            at: pos.col,
            projectRoot: workspace?.projectRoot
        ) {
            return false
        }
        return true
    }

    // MARK: - Coordinate helpers

    /// ウィンドウ座標を SwiftTerm のセル座標 (col, bufferRow) に変換する。
    /// `getOptimalFrameSize` から逆算した cellWidth/Height を使う (cellDimension は internal)。
    /// scroller を使う構成 (legacy) では右端の scroller 領域が `getOptimalFrameSize` に含まれ、
    /// 計算上はそれを差し引く。overlay scroller では scrollerWidth = 0 となる。
    private func cellPosition(at locationInWindow: CGPoint) -> (col: Int, bufferRow: Int)? {
        guard terminal.cols > 0, terminal.rows > 0, bounds.height > 0 else { return nil }
        let optimal = getOptimalFrameSize()
        let scrollerWidth = NSScroller.scrollerWidth(
            for: .regular,
            scrollerStyle: NSScroller.preferredScrollerStyle
        )
        let effectiveWidth = max(1, optimal.width - scrollerWidth)
        let cellWidth = effectiveWidth / CGFloat(terminal.cols)
        let cellHeight = optimal.height / CGFloat(terminal.rows)
        guard cellWidth > 0, cellHeight > 0 else { return nil }

        let point = convert(locationInWindow, from: nil)
        let col = Int(point.x / cellWidth)
        // NSView デフォルトの座標系は origin が左下なので flip して row を計算する
        let displayRow = Int((bounds.height - point.y) / cellHeight)
        guard col >= 0, col < terminal.cols,
              displayRow >= 0, displayRow < terminal.rows else { return nil }
        let bufferRow = displayRow + terminal.buffer.yDisp
        return (col, bufferRow)
    }
}

/// SwiftTerm の terminalDelegate をラップし、URL 起動と PTY 出力通知をフックするプロキシ。
/// クリック判定 (tap vs drag) は `PersistentTerminalView.lastInteractionWasTap` を参照する。
final class TerminalLinkGuard: NSObject, TerminalViewDelegate {
    private weak var original: (any TerminalViewDelegate)?

    init(original: any TerminalViewDelegate) {
        self.original = original
    }

    /// URL クリック起動。直前の mouseDown→mouseUp が「単純クリック」だったときだけ開く。
    /// ドラッグ選択直後の mouseUp が URL 上で発火しても、tap フラグが false なので無視される。
    /// Cmd 修飾キーの押下は要求しない (issue #71)。
    /// scheme を持つ URL のみ対象とし、SwiftTerm が link 判定したファイルパス文字列
    /// (例: `Sources/Foo.swift`) はここでは無視する — 実体は scheme なしの URL になり、
    /// `NSWorkspace.shared.open` に渡すと Finder が `-50` ダイアログを出してしまうため。
    /// ファイルパスのクリック起動は `PersistentTerminalView.handlePathClickIfNeeded` が担う。
    func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {
        guard let view = source as? PersistentTerminalView,
              view.lastInteractionWasTap,
              let url = URL(string: link),
              let scheme = url.scheme,
              !scheme.isEmpty else { return }
        NSWorkspace.shared.open(url)
    }

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        original?.send(source: source, data: data)
        // PTY へのキー入力を Claude セッションに通知 (issue #45)。Enter 検知で markBusy するため。
        (source as? PersistentTerminalView)?.onKeySend?(data)
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
        // PTY 出力によりバッファが更新されたとき Claude セッションの isBusy 追跡に通知する (issue #45)。
        // スクロール操作でも発火するが、issue #45 の実運用上は 0.5s デバウンスで無害と判断。
        (source as? PersistentTerminalView)?.onTerminalOutput?()
    }
}
