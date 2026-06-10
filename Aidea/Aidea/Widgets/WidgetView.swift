//
//  WidgetView.swift
//  Aidea
//

import SwiftUI

/// `AppHeaderView` 右端に常駐する widget 集約コンテナ。
/// 各 widget を背景付きでラップし、下部に対応するショートカットキーを小さく表示する。
/// ショートカットは widget の高さによらずヘッダ最下部で揃うよう、各セルを最大高に伸ばして下端に置く。
/// 各セルの横幅は中身の固有幅ぶんだけに保つため、コンテナ全体を `fixedSize` で確定する。
/// docs/specs/widgets/README.md 参照。
struct WidgetView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            chrome("⌘M") { QuickMemoButton() }
            chrome("⌥⌘S") { SchedulerView() }
            chrome("⌥⌘P") { TimerView() }
            chrome("⌥⌘C") { RemindView() }
            chrome(nil) { ClockView() }
        }
        .fixedSize()
    }

    /// widget を背景付きでラップし、下部にショートカットキーを表示する。
    /// `shortcut` が nil の widget (時計など) はキー表示なし。
    /// 各セルは `maxHeight: .infinity` で最も高い widget に高さを揃える。
    /// content は上下の `Spacer` で挟んで縦中央に置き、ショートカットだけ下端に固定する。
    /// 背景はヘッダ (windowBackground) と区別できるよう primary を薄く重ねた色にする。
    private func chrome<Content: View>(_ shortcut: String?, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 1) {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
            if let shortcut {
                Text(shortcut)
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(0.06))
        )
    }
}
