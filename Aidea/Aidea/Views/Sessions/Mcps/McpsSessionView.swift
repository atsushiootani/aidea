//
//  McpsSessionView.swift
//  Aidea
//

import SwiftUI

/// MCPs Session の SwiftUI View。McpsSessionState を参照する。
struct McpsSessionView: View {
    @Bindable var state: McpsSessionState

    var body: some View {
        List(state.loader.servers, selection: $state.selection) { server in
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name).font(.headline)
                Text("\(server.command) \(server.args.joined(separator: " "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .tag(server.id)
        }
        .onAppear { state.loader.reload() }
    }
}
