//
//  CompanionView.swift
//  Aidea
//

import SwiftUI

/// 9 体のコンパニオンアイコンを常時表示する View。
/// タップで Claude セッションを起動/フォーカスする。
struct CompanionView: View {
    @Environment(CompanionStore.self) private var store
    @Environment(SessionRegistry.self) private var registry
    @Environment(LayoutConfig.self) private var layout
    @Environment(RecommendState.self) private var recommend

    @State private var editingCompanion: CompanionConfig?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ForEach(store.companions) { companion in
                    companionIcon(companion: companion)
                }
            }

            // レコメンドモード: 選択中コンパニオンの下に吹き出しを表示
            if recommend.isActive {
                HStack(spacing: 0) {
                    // 選択中コンパニオンの位置にオフセット (各アイコン幅60 + spacing6)
                    Spacer().frame(width: CGFloat(recommend.selectedCompanionIndex) * 66)
                    RecommendBubbleView()
                }
            }
        }
        .sheet(item: $editingCompanion) { companion in
            CompanionEditView(companion: companion) { updated in
                store.update(updated)
            }
        }
    }

    /// コンパニオンアイコン 1 つ分の View
    private func companionIcon(companion: CompanionConfig) -> some View {
        let isActive = companion.sessionID != nil
        let isActiveTab: Bool = {
            guard let sessionID = companion.sessionID else { return false }
            return registry.activeSessionID == sessionID
        }()

        return VStack(spacing: 2) {
            // メインアイコン: タップで起動/フォーカス
            Button {
                if let sessionID = companion.sessionID {
                    registry.activateSession(sessionID)
                } else {
                    launchCompanion(companion)
                }
            } label: {
                Image(CompanionIconPresets.thumbnailIcon(for: companion.icon))
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isActiveTab ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .saturation(isActive ? 1.0 : 0.3)
                    .opacity(isActive ? 1.0 : 0.5)
            }
            .buttonStyle(.plain)
            .help(companion.name)

            // 名前ラベル: タップで編集
            Text(companion.name)
                .font(.system(size: 9))
                .foregroundStyle(isActiveTab ? Color.accentColor : (isActive ? Color.primary : Color.secondary))
                .lineLimit(1)
                .frame(width: 60)
                .onTapGesture {
                    editingCompanion = companion
                }
        }
    }

    /// コンパニオンに紐付く Claude セッションを起動する
    private func launchCompanion(_ companion: CompanionConfig) {
        let instance = layout.nextSessionInstance(of: .claude)
        let session = registry.createSession(tool: .claude, instance: instance)
        let id = session.id
        if let state = session.state as? ClaudeSessionState {
            state.companionPrompt = companion.initialPrompt
        }
        store.bind(index: companion.index, sessionID: id)

        if let pane = registry.activePane ?? layout.allPanes.first {
            pane.tabs.append(id)
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
        }
    }
}
