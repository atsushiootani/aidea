//
//  ScopeTagView.swift
//  Aidea
//

import SwiftUI

/// USER / PROJECT スコープを表すバッジ View。サイドバーの行末に表示する。
struct ScopeTagView: View {
    let scope: ResourceScope

    var body: some View {
        Text(scope.label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(scope == .project ? Color.blue : Color.orange.opacity(0.6))
            .clipShape(Capsule())
    }
}
