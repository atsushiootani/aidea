//
//  SessionFocusBridge.swift
//  Aidea
//

import AppKit

/// AppKit 系 SessionState のフォーカス契約 (C1 / C2 / C3) を担う非永続ヘルパ。
///
/// 各 AppKit 系 SessionState が 1 つインスタンスを保持し、
/// `didBecomeActive` / `didResignActive` でそれぞれ `activate()` / `deactivate()` を呼ぶ。
/// AppKit Window API (`makeFirstResponder` 等) はこのクラス内だけに閉じる。
/// 仕様は `docs/specs/sessions/focus-contract.md` を参照。
final class SessionFocusBridge {
    /// フォーカス対象の NSView への弱参照。所有権は SessionState 側 (lazy property 等)。
    private weak var view: NSView?

    /// 外部から読み取るための公開プロパティ。
    /// SessionRegistry の NSEvent クリックハンドラが「この Session の領域にクリックが入ったか」
    /// を isDescendant(of:) で判定するために使う。
    var trackedView: NSView? { view }

    /// `activate()` 時に view が nil だった場合のフラグ。
    /// `setView(_:)` で non-nil が入った瞬間に解消する。
    private var pendingActivation = false

    /// View 側 (NSViewRepresentable) が `makeNSView` 内で呼ぶ。
    /// nil 代入も有効 (子 View 切替で純 SwiftUI コンテンツに変わる場合等)。
    func setView(_ view: NSView?) {
        self.view = view
        if pendingActivation, let v = view {
            pendingActivation = false
            scheduleMakeFirstResponder(v)
        }
    }

    /// 契約 C1: SessionState.didBecomeActive から呼ぶ。
    /// view が non-nil なら firstResponder にセット、nil なら pending を立てて待機する。
    func activate() {
        if let v = view {
            scheduleMakeFirstResponder(v)
        } else {
            pendingActivation = true
        }
    }

    /// 契約 C2: SessionState.didResignActive から呼ぶ。
    /// 自分配下の NSView が firstResponder のときだけ解放する。
    func deactivate() {
        pendingActivation = false
        releaseIfOurs()
    }

    /// 契約 C3: View 破棄時 (`sessionFocusCleanup` modifier 経由) に呼ぶ。
    /// deactivate と同じ判定で firstResponder を解放する。
    /// 「自分配下のときだけ解放」が必須 (次のアクティブ Session が既に取得済の場合があるため)。
    func releaseIfOurs() {
        guard let v = view,
              let win = v.window,
              let fr = win.firstResponder as? NSView,
              fr === v || fr.isDescendant(of: v) else { return }
        win.makeFirstResponder(nil)
    }

    /// `makeFirstResponder` を次のメインスレッドサイクルで発火する。
    /// 発火時に `v.window == nil` (SwiftUI が NSHostingView 階層へ view を組み込む前) の場合は、
    /// attach されるまで最大 `remainingAttempts` 回リトライする (runaway 防止の上限)。
    /// 新規 Session の Tab キー等で、View の生成と activate() が同じ runloop サイクルで起きる
    /// ケースで v.window が間に合わないバグを回避する。
    private func scheduleMakeFirstResponder(_ view: NSView, remainingAttempts: Int = 5) {
        DispatchQueue.main.async { [weak view, weak self] in
            guard let v = view else { return }
            if let win = v.window {
                win.makeFirstResponder(v)
            } else if remainingAttempts > 0 {
                self?.scheduleMakeFirstResponder(v, remainingAttempts: remainingAttempts - 1)
            }
        }
    }
}

/// AppKit 系 SessionState が準拠する optional protocol。
/// View modifier (`sessionFocusCleanup`) から bridge にアクセスするためのインターフェース。
/// 純 SwiftUI 系 SessionState はこの protocol に準拠しない。
protocol FocusBridgeOwner {
    /// SessionState が保持する SessionFocusBridge インスタンス
    var focusBridge: SessionFocusBridge { get }
}
