//
//  StatusBubbleView.swift
//  Aidea
//

import SwiftUI

/// Companion アイコン上部に表示する作業状態フキダシ (issue #281)。
/// 文面の決定ロジックは StatusState.bubbleText(for:) を参照
/// (仕様: docs/specs/companions/companion.md#フキダシ表示-issue-281)。
struct StatusBubbleView: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: 92)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            // 吹き出しの三角 (下向き)。Triangle 本体は RecommendBubbleView.swift で定義済み (上向き) を 180° 回転。
            Triangle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 10, height: 6)
                .rotationEffect(.degrees(180))
        }
        .fixedSize()
    }
}
