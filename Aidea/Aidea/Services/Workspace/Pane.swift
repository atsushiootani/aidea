//
//  Pane.swift
//  Aidea
//

import Foundation
import Observation

/// 1 つの物理ペインが保持する Tab のリストとアクティブなタブ位置。
/// 各 Tab は 1 つの Session を参照する。
@Observable
final class Pane: Identifiable {
    let id: UUID
    var tabs: [SessionID]
    var activeIndex: Int

    init(id: UUID = UUID(), tabs: [SessionID], activeIndex: Int = 0) {
        self.id = id
        self.tabs = tabs
        self.activeIndex = activeIndex
    }

    /// 現在アクティブな SessionID。tabs が空なら nil。
    var activeSessionID: SessionID? {
        guard activeIndex >= 0, activeIndex < tabs.count else { return nil }
        return tabs[activeIndex]
    }
}
