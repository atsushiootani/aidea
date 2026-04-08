//
//  RightPaneView.swift
//  Aidea
//

import SwiftUI

/// 右ペイン。Web タブと Preview タブを切り替えられる。
/// ファイル選択時は自動で Preview タブに切り替わる。
struct RightPaneView: View {
    @Environment(WorkspaceState.self) private var workspace
    @State private var tab: RightPaneTab = .web

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(RightPaneTab.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            switch tab {
            case .web:
                WebView(url: URL(string: "https://www.apple.com")!)
            case .preview:
                FilePreviewView()
            }
        }
        .onChange(of: workspace.selectedFile) { _, newValue in
            if newValue != nil { tab = .preview }
        }
    }
}

/// 右ペインのタブ種別
enum RightPaneTab: String, CaseIterable, Identifiable {
    case web, preview
    var id: String { rawValue }
    var label: String {
        switch self {
        case .web:     return "Web"
        case .preview: return "Preview"
        }
    }
}
