//
//  PaneView.swift
//  Aidea
//

import SwiftUI

/// 1 つの物理ペインを表す容器 View。複数の Tab (=Session への参照) をタブバーで切り替え、
/// 「+」ボタンで新しい Session を追加、「x」ボタンでタブを閉じることができる。
struct PaneView: View {
    @Bindable var pane: Pane
    /// このペインが属する LayoutNode。split / removeLeaf 操作で使う。
    let layoutNode: LayoutNode
    @Environment(SessionRegistry.self) private var registry
    @Environment(LayoutConfig.self) private var layout

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            sessionStack
        }
    }

    /// すべての Tab の Session View を ZStack で常時レンダリングし、
    /// 非アクティブなものは opacity 0 で隠す。
    /// これで NSView が superview から外れず、Terminal 等の内部バッファが失われない。
    private var sessionStack: some View {
        ZStack {
            if pane.tabs.isEmpty {
                emptyTab
            } else {
                ForEach(pane.tabs, id: \.self) { id in
                    let isActive = (pane.activeSessionID == id)
                    registry.view(for: id)
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                registry.activeSessionID = id
                            }
                        )
                }
            }
        }
    }

    /// タブバー: 左側はスクロール可能な Tab 領域、右端に分割ボタンを固定配置する
    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    TabSlotView(pane: pane, index: 0)
                    ForEach(Array(pane.tabs.enumerated()), id: \.element) { index, sessionID in
                        tabItem(sessionID: sessionID, index: index)
                        TabSlotView(pane: pane, index: index + 1)
                    }
                    addButton
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
            splitButtons
                .padding(.trailing, 6)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// ペインを左右 / 上下に分割するボタン (タブバーの右端)
    /// 分割操作は SwiftUI の update サイクル外で実行するため DispatchQueue で遅延させる。
    private var splitButtons: some View {
        HStack(spacing: 4) {
            Button {
                let node = layoutNode
                let lay = layout
                DispatchQueue.main.async {
                    lay.splitLeaf(node, axis: .horizontal)
                }
            } label: {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("左右に分割")

            Button {
                let node = layoutNode
                let lay = layout
                DispatchQueue.main.async {
                    lay.splitLeaf(node, axis: .vertical)
                }
            } label: {
                Image(systemName: "rectangle.split.1x2")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("上下に分割")
        }
        .padding(.horizontal, 4)
    }

    /// 1 つの Tab。クリックでアクティブ化、× でクローズ。
    /// 青いアクティブ表示は Window 全体で 1 つだけ (registry.activeSessionID と一致する Tab のみ)。
    private func tabItem(sessionID: SessionID, index: Int) -> some View {
        let isGlobalActive = (registry.activeSessionID == sessionID)
        let isPaneActive = (index == pane.activeIndex)
        return HStack(spacing: 5) {
            Image(systemName: sessionID.tool.systemImageName)
                .font(.system(size: 11, weight: isGlobalActive ? .bold : .regular))
                .foregroundStyle(isGlobalActive ? Color.white : Color.secondary)
            Text(displayLabel(for: sessionID))
                .font(.system(size: 12, weight: isGlobalActive ? .bold : (isPaneActive ? .semibold : .regular)))
                .foregroundStyle(isGlobalActive ? Color.white : Color.primary)
            Button {
                closeTab(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isGlobalActive ? Color.white.opacity(0.85) : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isGlobalActive
                      ? Color.accentColor
                      : (isPaneActive ? Color.secondary.opacity(0.15) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isGlobalActive ? Color.clear : Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            pane.activeIndex = index
            registry.activeSessionID = sessionID
        }
        .draggable(sessionID)
    }

    /// タブヘッダの表示名。
    /// - Preview: state.title があればそれ、なければ URL の lastPathComponent、どちらも無ければ "Preview"
    /// - その他: tool 名 + (instance > 0 のとき番号)
    private func displayLabel(for sessionID: SessionID) -> String {
        if sessionID.tool == .preview,
           let preview = registry.state(for: sessionID) as? PreviewSessionState {
            if let title = preview.title, !title.isEmpty { return title }
            if let url = preview.url { return url.lastPathComponent }
        }
        if sessionID.instance == 0 { return sessionID.tool.displayName }
        return "\(sessionID.tool.displayName) \(sessionID.instance + 1)"
    }

    /// 追加メニュー (+) ボタン。シングルトン制約のある tool は条件付きで非表示。
    private var addButton: some View {
        Menu {
            ForEach(Tool.allCases) { tool in
                if isAddable(tool) {
                    Button {
                        addSession(tool: tool)
                    } label: {
                        Label(tool.displayName, systemImage: tool.systemImageName)
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11))
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// 指定 tool が追加可能か。Filer はアプリ全体で 1 つだけ持てる仕様。
    private func isAddable(_ tool: Tool) -> Bool {
        if tool == .filer {
            return !layout.allPanes.contains { pane in
                pane.tabs.contains { $0.tool == .filer }
            }
        }
        return true
    }

    /// タブが空の状態のプレースホルダー
    private var emptyTab: some View {
        VStack {
            Spacer()
            Text("タブを追加してください")
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 新しい Session を追加 (常に新インスタンスを採番)
    private func addSession(tool: Tool) {
        let instance = layout.nextSessionInstance(of: tool)
        let id = SessionID(tool, instance: instance)
        pane.tabs.append(id)
        pane.activeIndex = pane.tabs.count - 1
        registry.activeSessionID = id
    }

    /// タブをクローズ。クローズ対象がグローバルアクティブだった場合は更新する。
    /// 全タブが閉じられた場合、このペイン自体をレイアウトツリーから取り除く。
    private func closeTab(at index: Int) {
        guard index >= 0, index < pane.tabs.count else { return }
        let closed = pane.tabs[index]
        pane.tabs.remove(at: index)
        if pane.activeIndex >= pane.tabs.count {
            pane.activeIndex = max(0, pane.tabs.count - 1)
        }
        if registry.activeSessionID == closed {
            registry.activeSessionID = pane.activeSessionID
        }
        // 全タブが閉じられたらペイン自体を削除 (update サイクル外で実行)
        if pane.tabs.isEmpty {
            let node = layoutNode
            let lay = layout
            let reg = registry
            DispatchQueue.main.async {
                lay.removeLeaf(node)
                if let firstPane = lay.allPanes.first {
                    reg.activeSessionID = firstPane.activeSessionID
                }
            }
        }
    }
}
