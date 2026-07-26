//
//  TabVisibilityEnvironment.swift
//  Aidea
//

import SwiftUI

extension EnvironmentValues {
    /// このタブがペインの表示中タブ (アクティブタブ) かどうか。
    /// PaneView の ZStack 常駐レンダリング (ADR 0019) では非表示タブの View も生き続けるため、
    /// 描画停止などの省力化 (issue #273) の判定に使う。
    /// 仕様: docs/specs/sessions/terminal.md#非表示タブの描画停止-issue-273
    @Entry var isTabVisible: Bool = true
}
