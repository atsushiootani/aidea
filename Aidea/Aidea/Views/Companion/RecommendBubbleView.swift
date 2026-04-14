//
//  RecommendBubbleView.swift
//  Aidea
//

import SwiftUI

/// コンパニオンアイコンの下に表示する吹き出し。レコメンドプロンプトを縦に並べる。
struct RecommendBubbleView: View {
    @Environment(RecommendState.self) private var recommend

    var body: some View {
        VStack(alignment: .leading, spacing: -1) {
            // 吹き出しの三角（左上）— 本体背景より明るくして視認性を確保
            Triangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 14, height: 8)
                .padding(.leading, 20)

            // プロンプト一覧
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(recommend.prompts.enumerated()), id: \.offset) { index, prompt in
                    let isSelected = index == recommend.selectedPromptIndex
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                        Text(prompt)
                            .font(.system(size: 12))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isSelected ? Color.accentColor : Color.clear)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .frame(width: 180)
    }
}

/// 吹き出しの三角形
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
