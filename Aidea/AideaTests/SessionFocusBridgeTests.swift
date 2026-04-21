//
//  SessionFocusBridgeTests.swift
//  AideaTests
//

import Testing
import AppKit
@testable import Aidea

/// SessionFocusBridge の単体テスト。
/// 契約 C1 / C2 / C3 の期待挙動と pending パターンを検証する。
@MainActor
struct SessionFocusBridgeTests {

    /// firstResponder を取れる簡易テスト用 NSView
    private final class FocusableTestView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    /// Window + content view を生成して返すユーティリティ
    private func makeWindow(content: NSView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = content
        return window
    }

    /// DispatchQueue.main.async の完了を待つ
    private func drainMainQueue() async {
        await withCheckedContinuation { cont in
            DispatchQueue.main.async { cont.resume() }
        }
    }

    // MARK: - 契約 C1: activate

    @Test
    func activate_withViewSet_setsFirstResponder() async throws {
        let view = FocusableTestView()
        let window = makeWindow(content: view)
        let bridge = SessionFocusBridge()

        bridge.setView(view)
        bridge.activate()
        await drainMainQueue()

        #expect(window.firstResponder === view)
    }

    @Test
    func activate_withoutView_setsPending_andResolvesOnSetView() async throws {
        let view = FocusableTestView()
        let window = makeWindow(content: view)
        let bridge = SessionFocusBridge()

        // view 未設定で activate → pending 状態
        bridge.activate()
        await drainMainQueue()
        #expect(window.firstResponder !== view, "view 未設定なら firstResponder は変わらない")

        // 後から setView で解消
        bridge.setView(view)
        await drainMainQueue()
        #expect(window.firstResponder === view, "setView で pending が解消されて firstResponder になる")
    }

    @Test
    func activate_withoutView_setViewNil_doesNotResolve() async throws {
        let view = FocusableTestView()
        let window = makeWindow(content: view)
        let bridge = SessionFocusBridge()

        bridge.activate()
        bridge.setView(nil)
        await drainMainQueue()

        #expect(window.firstResponder !== view, "nil 代入では pending は解消されない")
    }

    // MARK: - 契約 C2: deactivate

    @Test
    func deactivate_releasesWhenOurFirstResponder() async throws {
        let view = FocusableTestView()
        let window = makeWindow(content: view)
        let bridge = SessionFocusBridge()

        bridge.setView(view)
        bridge.activate()
        await drainMainQueue()
        #expect(window.firstResponder === view)

        bridge.deactivate()
        #expect(window.firstResponder !== view, "自分配下の firstResponder は解放される")
    }

    @Test
    func deactivate_leavesOthersAlone() async throws {
        let ourView = FocusableTestView()
        let otherView = FocusableTestView()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        container.addSubview(ourView)
        container.addSubview(otherView)
        let window = makeWindow(content: container)
        let bridge = SessionFocusBridge()

        bridge.setView(ourView)

        // 別の View が firstResponder を持っている状態を作る
        _ = window.makeFirstResponder(otherView)
        #expect(window.firstResponder === otherView)

        bridge.deactivate()
        #expect(window.firstResponder === otherView, "他人配下の firstResponder は奪わない")
    }

    @Test
    func deactivate_clearsPendingFlag() async throws {
        let view = FocusableTestView()
        let window = makeWindow(content: view)
        let bridge = SessionFocusBridge()

        // pending を立ててから deactivate
        bridge.activate()    // view nil → pending
        bridge.deactivate()  // pending をクリア

        // その後 setView しても pending は解消しない (activate されていないので当然発火しない)
        bridge.setView(view)
        await drainMainQueue()
        #expect(window.firstResponder !== view, "deactivate 後は setView で自動フォーカスしない")
    }

    // MARK: - 契約 C3: releaseIfOurs

    @Test
    func releaseIfOurs_sameBehaviorAsDeactivate() async throws {
        let view = FocusableTestView()
        let window = makeWindow(content: view)
        let bridge = SessionFocusBridge()

        bridge.setView(view)
        bridge.activate()
        await drainMainQueue()
        #expect(window.firstResponder === view)

        bridge.releaseIfOurs()
        #expect(window.firstResponder !== view)
    }

    @Test
    func releaseIfOurs_handlesDescendantFirstResponder() async throws {
        let parent = FocusableTestView()
        let child = FocusableTestView()
        parent.addSubview(child)
        let window = makeWindow(content: parent)
        let bridge = SessionFocusBridge()

        bridge.setView(parent)  // 親を登録
        _ = window.makeFirstResponder(child)  // 子が firstResponder
        #expect(window.firstResponder === child)

        bridge.releaseIfOurs()
        #expect(window.firstResponder !== child, "子孫 View が firstResponder の場合も解放される")
    }

    // MARK: - setView の基本動作

    @Test
    func setView_replacesReference() async throws {
        let view1 = FocusableTestView()
        let view2 = FocusableTestView()
        let window = makeWindow(content: view1)
        window.contentView?.addSubview(view2)
        let bridge = SessionFocusBridge()

        bridge.setView(view1)
        bridge.activate()
        await drainMainQueue()
        #expect(window.firstResponder === view1)

        // view を差し替え。activate を再度呼ばない限り自動フォーカスはしない設計
        bridge.setView(view2)
        await drainMainQueue()
        #expect(window.firstResponder === view1, "setView 単独では firstResponder は変わらない")

        // view1 が firstResponder を握ったまま deactivate を呼ぶと解放されない
        // (bridge は view2 を参照しているので view1 は自分配下扱いではない)
        bridge.deactivate()
        #expect(window.firstResponder === view1, "bridge の参照が別 View に移った後は元の view を触らない")
    }
}
