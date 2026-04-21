//
//  FirstResponderLogger.swift
//  Aidea
//

import AppKit
import SwiftUI

/// NSWindow.firstResponder の変化を KVO で監視してコンソールに出力するデバッグヘルパ。
/// ContentView で `.background(FirstResponderLoggerAttachment())` として仕込むと、
/// Window が生成されたタイミングで自動的に購読を開始する。
///
/// 出力フォーマット:
///   [FirstResponder] ClassName#hash → NewClassName#hash  session=<tool:instance> descendantOf=<desc>
final class FirstResponderLogger {
    static let shared = FirstResponderLogger()

    private var observation: NSKeyValueObservation?
    private weak var attachedWindow: NSWindow?
    private weak var registry: SessionRegistry?

    private init() {}

    /// Window に購読を取り付ける。既に別 Window に取り付け済なら解除してから張り替え。
    func attach(to window: NSWindow, registry: SessionRegistry?) {
        if attachedWindow === window { return }
        detach()
        attachedWindow = window
        self.registry = registry
        observation = window.observe(\.firstResponder, options: [.old, .new]) { [weak self] win, change in
            guard let self else { return }
            self.log(
                old: change.oldValue.flatMap { $0 },
                new: change.newValue.flatMap { $0 },
                window: win
            )
        }
        print("[FirstResponder] logger attached to window \(ObjectIdentifier(window).hashValue & 0xFFFFFF)")
    }

    /// 購読を解除する
    func detach() {
        observation?.invalidate()
        observation = nil
        attachedWindow = nil
        registry = nil
    }

    /// 現在の firstResponder を起点に、その View がどの Session の配下かを特定する文字列を返す。
    ///
    /// - AppKit 系 (FocusBridgeOwner): `trackedView` の配下かで判定 (確実)
    /// - 純 SwiftUI 系 (Kit 等): trackedView がないので activeSessionID を使った推測表示 (末尾に "~")
    /// - Window 自身または該当なし: "-"
    private func owningSessionLabel(for responder: NSResponder?) -> String {
        guard let responder, let registry else { return "-" }
        // Window 自身が firstResponder のケース (契約 I3 "空許容")
        if responder === attachedWindow { return "-" }
        guard let view = responder as? NSView else { return "-" }
        // 1. FocusBridgeOwner の trackedView 配下かを確実判定
        for session in registry.sessions {
            if let owner = session.state as? FocusBridgeOwner,
               let tracked = owner.focusBridge.trackedView,
               view === tracked || view.isDescendant(of: tracked) {
                return "\(session.id.tool.rawValue):\(session.id.instance)"
            }
        }
        // 2. どれにも属さない場合はアクティブ Session による推測表示 ("~" 付与)。
        //    純 SwiftUI 系 Session (Kit 等) の KeyViewProxy / internal focus proxy を扱うための fallback。
        if let active = registry.activeSessionID {
            return "\(active.tool.rawValue):\(active.instance)~"
        }
        return "-"
    }

    /// KVO コールバック。ログ出力を整形する。
    /// 同一オブジェクト間の遷移 (AppKit 内部の再代入や KVO の空振り通知) はスキップする。
    private func log(old: NSResponder?, new: NSResponder?, window: NSWindow) {
        if old === new { return }
        let oldDesc = describe(old)
        let newDesc = describe(new)
        let owner = owningSessionLabel(for: new)
        let winID = ObjectIdentifier(window).hashValue & 0xFFFFFF
        print("[FirstResponder] \(oldDesc) → \(newDesc)  session=\(owner)  win=\(winID)")
    }

    /// NSResponder を `ClassName#hash` 形式で表示。Window 自身や nil も扱う。
    private func describe(_ responder: NSResponder?) -> String {
        guard let r = responder else { return "nil" }
        let name = String(describing: type(of: r))
        let hash = ObjectIdentifier(r).hashValue & 0xFFFFFF
        return "\(name)#\(String(hash, radix: 16))"
    }
}

/// ContentView 等に background で仕込む透明 NSView。
/// Window に attach されたタイミングで FirstResponderLogger を起動する。
struct FirstResponderLoggerAttachment: NSViewRepresentable {
    let registry: SessionRegistry

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window {
                FirstResponderLogger.shared.attach(to: window, registry: registry)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            if let window = nsView?.window {
                FirstResponderLogger.shared.attach(to: window, registry: registry)
            }
        }
    }
}
