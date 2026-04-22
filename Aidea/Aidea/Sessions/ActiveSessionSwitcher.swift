//
//  ActiveSessionSwitcher.swift
//  Aidea
//

import SwiftUI
import AppKit

/// Ctrl+Tab で表示する Session 履歴切替ウィンドウのコントローラ。
/// 仕様は docs/specs/window/active-session-switcher.md を参照。
///
/// - keyDown 監視 (常駐): Ctrl+Tab / Ctrl+Shift+Tab を検出
/// - flagsChanged 監視 (表示中だけ): Ctrl リリースで確定
/// - NSWindow を borderless overlay として表示し、SwiftUI View をホストする
@Observable
final class ActiveSessionSwitcher {
    /// 表示中かどうか (View が観測する)
    private(set) var isVisible: Bool = false
    /// 表示するエントリ (activeSessionHistory.reversed() のスナップショット)
    private(set) var entries: [SessionID] = []
    /// 選択中のエントリ index (0 = リスト先頭 = 最新)
    private(set) var selectedIndex: Int = 0

    @ObservationIgnored private weak var registry: SessionRegistry?
    @ObservationIgnored private weak var companionStore: CompanionStore?
    @ObservationIgnored private var window: NSWindow?
    @ObservationIgnored private var keyDownMonitor: Any?
    @ObservationIgnored private var flagsChangedMonitor: Any?
    @ObservationIgnored private var isInstalled: Bool = false

    /// アプリ起動時に一度呼ぶ。Ctrl+Tab を待つ keyDown ローカルモニターを常駐させる。
    /// registry / companionStore は Window 単位の依存を保持する。
    func install(registry: SessionRegistry, companionStore: CompanionStore) {
        self.registry = registry
        self.companionStore = companionStore
        guard !isInstalled else { return }
        isInstalled = true
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event)
        }
    }

    // MARK: - Key handling

    /// keyDown ローカルモニターのコールバック。
    /// Ctrl+Tab を捕捉し、ウィンドウ表示中はその他のキーも全て吸収する (no-op)。
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCtrlTab = event.keyCode == 48 && mods.contains(.control) && !mods.contains(.command) && !mods.contains(.option)
        if isCtrlTab {
            let isShift = mods.contains(.shift)
            if isVisible {
                moveSelection(by: isShift ? -1 : 1)
            } else {
                show()
            }
            return nil // 吸収
        }
        // 表示中の他のキーは全て no-op として吸収する (仕様)
        if isVisible {
            return nil
        }
        return event
    }

    /// flagsChanged ローカルモニターのコールバック。
    /// Control が外れた瞬間に確定する。
    private func handleFlagsChanged(_ event: NSEvent) -> NSEvent? {
        guard isVisible else { return event }
        if !event.modifierFlags.contains(.control) {
            confirm()
        }
        return event
    }

    // MARK: - State transitions

    /// Switcher を表示する。履歴 0/1 件なら no-op。初期選択は index 1 (= "直前の Session")。
    private func show() {
        guard let registry else { return }
        let snapshot = Array(registry.activeSessionHistory.reversed())
        guard snapshot.count >= 2 else { return }
        entries = snapshot
        selectedIndex = 1 // 履歴 2 番目
        isVisible = true
        showWindow()
        installFlagsMonitor()
    }

    /// 選択を offset だけ移動 (端でクランプ、循環しない)。
    private func moveSelection(by offset: Int) {
        guard !entries.isEmpty else { return }
        let new = selectedIndex + offset
        selectedIndex = max(0, min(entries.count - 1, new))
    }

    /// Ctrl リリースで呼ばれる。選択中 Session をアクティブ化してウィンドウを閉じる。
    private func confirm() {
        let id = entries.indices.contains(selectedIndex) ? entries[selectedIndex] : nil
        dismiss()
        if let id { registry?.activateSession(id) }
    }

    /// 表示終了。flagsChanged モニターも解除する。
    private func dismiss() {
        isVisible = false
        entries = []
        window?.orderOut(nil)
        if let m = flagsChangedMonitor {
            NSEvent.removeMonitor(m)
            flagsChangedMonitor = nil
        }
    }

    /// flagsChanged モニターを設置する (表示中のみ)。
    private func installFlagsMonitor() {
        guard flagsChangedMonitor == nil else { return }
        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            return self.handleFlagsChanged(event)
        }
    }

    // MARK: - Window

    /// borderless overlay window を生成 (初回のみ) → 中央配置 → 表示。
    private func showWindow() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.level = .floating
            win.hasShadow = true
            win.ignoresMouseEvents = true
            if let registry, let companionStore {
                win.contentView = NSHostingView(rootView: ActiveSessionSwitcherView(
                    switcher: self,
                    registry: registry,
                    companionStore: companionStore
                ))
            }
            window = win
        }
        // アクティブな Aidea Window の中央に配置
        if let win = window, let main = NSApp.keyWindow ?? NSApp.windows.first(where: { $0 !== win && $0.isVisible }) {
            let mainFrame = main.frame
            let s = win.frame.size
            win.setFrameOrigin(NSPoint(
                x: mainFrame.midX - s.width / 2,
                y: mainFrame.midY - s.height / 2
            ))
        }
        window?.orderFrontRegardless()
    }
}
