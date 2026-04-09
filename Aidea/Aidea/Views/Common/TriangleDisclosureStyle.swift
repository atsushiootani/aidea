//
//  TriangleDisclosureStyle.swift
//  Aidea
//

import SwiftUI

/// サイドバーのグループ折りたたみに使うカスタム DisclosureGroupStyle。
/// 閉じているとき: ▶ (右向きの塗りつぶし三角形)
/// 開いているとき: ▼ (下向き、回転で表現)
struct TriangleDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                    configuration.label
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 16)
            }
        }
    }
}
