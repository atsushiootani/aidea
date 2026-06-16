//
//  SnippetView.swift
//  Aidea
//

import SwiftUI

/// ヘッダ常駐のコードスニペット widget。`WidgetView` 内 SchedulerView の左隣に配置。
/// コードアイコン + 登録件数を表示し、クリックで `SnippetPopoverView` を開く。
/// docs/specs/widgets/snippets.md 参照。
struct SnippetView: View {
    @Environment(SnippetState.self) private var snippetState

    var body: some View {
        @Bindable var snippetState = snippetState
        Button {
            snippetState.isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 14))
                Text(labelText)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("コードスニペット (⌥⌘B)")
        .popover(isPresented: $snippetState.isPopoverPresented, arrowEdge: .top) {
            SnippetPopoverView()
        }
    }

    private var labelText: String {
        let count = snippetState.snippets.filter(\.isEnabled).count
        return count == 0 ? "なし" : "\(count)"
    }
}
