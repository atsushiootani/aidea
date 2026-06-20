//
//  DirectoryNameView.swift
//  Aidea
//

import SwiftUI

/// AppHeaderView の中央・上揃えに重ねて表示するディレクトリ名。
/// 現在のプロジェクトルートのディレクトリ名を **1 行・太字** で表示する (truncate しない)。
/// 仕様: docs/specs/aspects/view-hierarchy.md
struct DirectoryNameView: View {
    @Environment(WorkspaceState.self) private var workspace

    var body: some View {
        Text(workspace.projectRoot?.lastPathComponent ?? "")
            .font(.system(size: 10, design: .monospaced))
            .bold()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .help(workspace.projectRoot?.path ?? "")
    }
}
