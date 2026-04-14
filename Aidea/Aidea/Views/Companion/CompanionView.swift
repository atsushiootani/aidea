//
//  CompanionView.swift
//  Aidea
//

import SwiftUI

/// 8 体のコンパニオンアイコンを常時表示する View。
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
                ForEach(Array(CompanionIconPresets.imageIcons.enumerated()), id: \.offset) { index, icon in
                    let companion = store.companion(forIndex: index)
                    companionIcon(companion: companion, icon: icon, index: index)
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
                store.upsert(updated)
            }
        }
    }

    /// コンパニオンアイコン 1 つ分の View
    private func companionIcon(companion: CompanionConfig?, icon: String, index: Int) -> some View {
        let isActive = companion.map { store.isActive($0.id) } ?? false
        let isActiveTab: Bool = {
            guard let companion, let sessionID = store.activeSessionMap[companion.id] else { return false }
            return registry.activeSessionID == sessionID
        }()
        let name = companion?.name ?? "Companion \(index + 1)"

        return VStack(spacing: 2) {
            // メインアイコン: タップで起動/フォーカス
            Button {
                if let companion, isActive, let sessionID = store.activeSessionMap[companion.id] {
                    registry.activateSession(sessionID)
                } else {
                    let config = companion ?? store.createDefault(forIndex: index)
                    launchCompanion(config)
                }
            } label: {
                Image(icon)
                    .resizable()
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
            .help(name)

            // 名前ラベル: タップで編集
            Text(name)
                .font(.system(size: 9))
                .foregroundStyle(isActiveTab ? Color.accentColor : (isActive ? Color.primary : Color.secondary))
                .lineLimit(1)
                .frame(width: 60)
                .onTapGesture {
                    editingCompanion = companion ?? store.createDefault(forIndex: index)
                }
        }
    }

    /// コンパニオンに紐付く Claude セッションを起動する
    private func launchCompanion(_ companion: CompanionConfig) {
        // まだ store に登録されてなければ登録
        if store.companions.first(where: { $0.id == companion.id }) == nil {
            store.add(companion)
        }

        let instance = layout.nextSessionInstance(of: .claude)
        let session = registry.createSession(tool: .claude, instance: instance)
        let id = session.id
        if let state = session.state as? ClaudeSessionState {
            state.companionPrompt = companion.initialPrompt
        }
        store.bind(companionID: companion.id, sessionID: id)

        if let pane = registry.activePane ?? layout.allPanes.first {
            pane.tabs.append(id)
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
        }
    }
}
