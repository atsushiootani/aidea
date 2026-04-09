//
//  LayoutConfig.swift
//  Aidea
//

import Foundation
import Observation

/// 1 つの物理ペインが保持する Tab のリストとアクティブなタブ位置。
/// 各 Tab は 1 つの Session を参照する。
@Observable
final class Pane: Identifiable {
    let id = UUID()
    var tabs: [SessionID]
    var activeIndex: Int

    init(tabs: [SessionID], activeIndex: Int = 0) {
        self.tabs = tabs
        self.activeIndex = activeIndex
    }

    /// 現在アクティブな SessionID。tabs が空なら nil。
    var activeSessionID: SessionID? {
        guard activeIndex >= 0, activeIndex < tabs.count else { return nil }
        return tabs[activeIndex]
    }
}

/// 4 ペイン固定レイアウトでの Pane 集合。
/// Phase 2 で動的な LayoutTree に置き換える予定。
@Observable
final class LayoutConfig {
    let topLeft: Pane
    let bottomLeft: Pane
    let center: Pane
    let right: Pane

    init() {
        self.topLeft    = Pane(tabs: [SessionID(.filer)])
        self.bottomLeft = Pane(tabs: [SessionID(.skills), SessionID(.commands), SessionID(.mcps)])
        self.center     = Pane(tabs: [SessionID(.terminal)])
        self.right      = Pane(tabs: [SessionID(.web), SessionID(.preview)])
    }

    /// 全 Pane の配列 (Session ID 一意化のため横断的に参照する)
    var allPanes: [Pane] { [topLeft, bottomLeft, center, right] }

    /// 指定 tool の新しい Session インスタンス番号を採番する (全ペイン横断で未使用の最小値)
    func nextSessionInstance(of tool: Tool) -> Int {
        let used = Set(allPanes.flatMap { $0.tabs }.filter { $0.tool == tool }.map { $0.instance })
        var instance = 0
        while used.contains(instance) { instance += 1 }
        return instance
    }
}
