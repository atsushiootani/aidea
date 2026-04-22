//
//  ActiveSessionSwitcherView.swift
//  Aidea
//

import SwiftUI

/// Active Session Switcher のオーバーレイ Window 内で表示する SwiftUI View。
/// 仕様: docs/specs/window/active-session-switcher.md
///
/// 各エントリは Tool アイコン + Session 表示名のみ (プレビュー / 詳細情報なし)。
/// 選択中はアクセントカラーで強調。選択変更時は ScrollViewReader で自動追従する。
struct ActiveSessionSwitcherView: View {
    @Bindable var switcher: ActiveSessionSwitcher
    let registry: SessionRegistry
    let companionStore: CompanionStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(switcher.entries.enumerated()), id: \.offset) { index, id in
                        entryRow(index: index, id: id)
                            .id(index)
                    }
                }
                .padding(8)
            }
            .frame(width: 320, height: 480)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 20)
            .onChange(of: switcher.selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    /// 1 行のエントリ表示。Tool アイコン + Session 表示名。選択中はアクセントカラー背景。
    @ViewBuilder
    private func entryRow(index: Int, id: SessionID) -> some View {
        let isSelected = (index == switcher.selectedIndex)
        HStack(spacing: 8) {
            entryIcon(for: id, isSelected: isSelected)
                .frame(width: 18)
            Text(displayName(for: id))
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// エントリのアイコン。Claude はコンパニオン色付きの猫耳画像、それ以外は SF Symbol。
    /// PaneView.tabIcon と同じ規約に揃える。
    @ViewBuilder
    private func entryIcon(for id: SessionID, isSelected: Bool) -> some View {
        if id.tool == .claude {
            let tintColor = companionTintColor(for: id)
            Image("cat-ear-tab")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(isSelected ? Color.white : tintColor)
        } else {
            Image(systemName: id.tool.systemImageName)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.white : .secondary)
        }
    }

    /// Claude セッションに紐付くコンパニオンのテーマカラーを返す。
    /// PaneView.companionTintColor と同じ実装。
    private func companionTintColor(for sessionID: SessionID) -> Color {
        for (companionID, sid) in companionStore.activeSessionMap where sid == sessionID {
            if let companion = companionStore.companions.first(where: { $0.id == companionID }),
               let rgb = CompanionIconPresets.themeColors[companion.icon] {
                return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
            }
        }
        return Color.secondary
    }

    /// SessionID → 表示名の解決。PaneView.displayLabel と同じ規約に揃える。
    private func displayName(for id: SessionID) -> String {
        if id.tool == .preview,
           let s = registry.session(for: id),
           let preview = s.state as? PreviewSessionState {
            if let title = preview.title, !title.isEmpty { return title }
            if let url = preview.url { return url.lastPathComponent }
        }
        if id.tool == .gitDiff {
            return "Diff"
        }
        if id.tool == .claude,
           let name = companionStore.companionName(for: id) {
            return name
        }
        if id.instance == 0 { return id.tool.displayName }
        return "\(id.tool.displayName) \(id.instance + 1)"
    }
}
