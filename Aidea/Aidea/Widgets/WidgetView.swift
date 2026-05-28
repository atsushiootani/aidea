//
//  WidgetView.swift
//  Aidea
//

import SwiftUI

/// `AppHeaderView` 右端に常駐する widget 集約コンテナ。
/// `CompanionView` と兄弟関係で、ヘッダ常駐型の小さな補助機能をまとめて並べる。
/// 個別 widget の追加 / 削除に合わせて子ビューを増減させる。
/// docs/specs/widgets/README.md 参照。
struct WidgetView: View {
    var body: some View {
        HStack(spacing: 4) {
            RemindView()
            QuickMemoButton()
            TimerView()
        }
    }
}
