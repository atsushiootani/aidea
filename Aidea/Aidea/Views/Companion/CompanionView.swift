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
    @Environment(WorkspaceState.self) private var workspace
    @Environment(SpeechState.self) private var speech

    @State private var editingCompanion: CompanionConfig?

    /// Companion アイコンの 4 状態 (issue #45)。優先順位: speaking > busy > idle > inactive
    private enum IconState {
        case inactive   // セッション未起動
        case idle       // 起動済み、暇
        case busy       // Claude 実行中
        case speaking   // VOICEVOX 読み上げ中
    }

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
            CompanionEditView(
                companion: companion,
                onSave: { updated in store.update(updated) },
                onOpenInstructions: { openInstructions(for: companion.index) }
            )
        }
    }

    /// CompanionEditView の「指示書を開く」ボタンから呼ばれる。
    /// 指示書ファイルが不在なら BackchannelSetup が Bundle テンプレから生成し、
    /// SessionRegistry.openPreview で Preview セッションとして開く (markdown view + 編集モード対応)。
    private func openInstructions(for index: Int) {
        guard let projectRoot = workspace.projectRoot else { return }
        BackchannelSetup.setup(projectRoot: projectRoot)
        let url = CompanionInstructions.entrypointURL(projectRoot: projectRoot, index: index)
        let title = "Companion \(index + 1) 指示書"
        registry.openPreview(for: url, title: title)
    }

    /// コンパニオンアイコン 1 つ分の View
    private func companionIcon(companion: CompanionConfig) -> some View {
        let isActive = companion.sessionID != nil
        let isActiveTab: Bool = {
            guard let sessionID = companion.sessionID else { return false }
            return registry.activeSessionID == sessionID
        }()
        let iconState = resolveIconState(for: companion)
        let imageName = imageName(for: companion, state: iconState)

        return VStack(spacing: 2) {
            // メインアイコン: タップで起動/フォーカス
            Button {
                if let sessionID = companion.sessionID {
                    registry.activateSession(sessionID)
                } else {
                    launchCompanion(companion)
                }
            } label: {
                Image(imageName)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .overlay(alignment: .topTrailing) {
                        stateOverlay(for: iconState)
                            .padding(2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isActiveTab ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .saturation(iconState == .inactive ? 0.3 : 1.0)
                    .opacity(iconState == .inactive ? 0.5 : 1.0)
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

    /// 現在の Companion が取るべきアイコン状態を判定する (issue #45)。
    /// 優先順位は speaking > busy > idle > inactive。
    private func resolveIconState(for companion: CompanionConfig) -> IconState {
        guard let sessionID = companion.sessionID,
              let session = registry.session(for: sessionID),
              let claudeSessionState = session.state as? ClaudeSessionState else {
            return .inactive
        }
        if claudeSessionState.isSpeaking {
            return .speaking
        }
        else if claudeSessionState.isBusy {
            return .busy
        }
        else{
            return .idle
        }
    }

    /// 状態に応じたベース画像名を返す。normal/idle/inactive はサムネイル (小サイズ版) を使う。
    /// 表情画像は imageIcon → -smile / -thinking のマップで解決する (CompanionIconPresets)。
    private func imageName(for companion: CompanionConfig, state: IconState) -> String {
        switch state {
        case .speaking:
            return CompanionIconPresets.smileIcon(for: companion.icon)
        case .busy:
            return CompanionIconPresets.thinkingIcon(for: companion.icon)
        case .idle, .inactive:
            return CompanionIconPresets.thumbnailIcon(for: companion.icon)
        }
    }

    /// 状態オーバーレイ (コーナーバッジ風 SF Symbol)。idle / inactive は何も描かない。
    /// アイコンが背景画像に沈まないよう、SF Symbol の後ろに半透明の白角丸を敷いて視認性を上げる。
    @ViewBuilder
    private func stateOverlay(for state: IconState) -> some View {
        switch state {
        case .speaking:
            Image(systemName: "heart.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.pink)
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.6))
                )
        case .busy:
            Image(systemName: "ellipsis.bubble")
                .font(.system(size: 18))
                .foregroundStyle(Color(white: 0.25))
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.6))
                )
        case .idle, .inactive:
            EmptyView()
        }
    }

    /// コンパニオンに紐付く Claude セッションを起動する
    private func launchCompanion(_ companion: CompanionConfig) {
        let instance = layout.nextSessionInstance(of: .claude)
        let session = registry.createSession(tool: .claude, instance: instance)
        let id = session.id
        if let state = session.state as? ClaudeSessionState {
            state.companionPrompt = CompanionInstructions.loadCommand(for: companion.index)
            state.companionIndex = companion.index
            state.speechQueue = speech.queue
        }
        store.bind(index: companion.index, sessionID: id)

        if let pane = registry.activePane ?? layout.allPanes.first {
            pane.tabs.append(id)
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
        }
    }
}
