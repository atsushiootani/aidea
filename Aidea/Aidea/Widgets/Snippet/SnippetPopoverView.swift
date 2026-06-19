//
//  SnippetPopoverView.swift
//  Aidea
//

import SwiftUI

/// `SnippetView` から開かれる popover の本体。
/// スニペット一覧を表示し、追加・編集・削除・実行を popover 内で完結させる。
/// docs/specs/widgets/snippets.md 参照。
struct SnippetPopoverView: View {
    @State private var editing: EditTarget?

    @Environment(SnippetState.self) private var snippetState

    enum EditTarget: Identifiable {
        case new
        case existing(SnippetConfig.Snippet)

        var id: String {
            switch self {
            case .new: return "__new__"
            case .existing(let s): return s.id
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let editing {
                SnippetEditView(target: editing) { self.editing = nil }
            } else {
                list
            }
        }
        .padding(12)
        .frame(width: 400)
    }

    private var header: some View {
        HStack {
            Text("コードスニペット")
                .font(.headline)
            Spacer()
            if editing == nil {
                Button {
                    editing = .new
                } label: {
                    Label("追加", systemImage: "plus")
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        if snippetState.snippets.isEmpty {
            Text("スニペットなし")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(snippetState.snippets) { snippet in
                        SnippetRowView(
                            snippet: snippet,
                            onEdit: { editing = .existing(snippet) },
                            onDelete: { snippetState.deleteSnippet(snippetID: snippet.id) }
                        )
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }
}
