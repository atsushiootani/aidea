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
    @Environment(CompanionStore.self) private var companionStore
    @Environment(TabPickerAnchor.self) private var tabPickerAnchor

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
                                registry.setActiveTab(paneID: pane.id, tabIndex: pane.activeIndex)
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
    /// 新しく作られたペインのタブを自動で active にする。
    private var splitButtons: some View {
        HStack(spacing: 4) {
            Button {
                let node = layoutNode
                let lay = layout
                let reg = registry
                DispatchQueue.main.async {
                    if let newPane = lay.splitLeaf(node, axis: .horizontal) {
                        reg.setActiveTab(paneID: newPane.id, tabIndex: newPane.activeIndex)
                    }
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
                let reg = registry
                DispatchQueue.main.async {
                    if let newPane = lay.splitLeaf(node, axis: .vertical) {
                        reg.setActiveTab(paneID: newPane.id, tabIndex: newPane.activeIndex)
                    }
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
            tabIcon(sessionID: sessionID, isGlobalActive: isGlobalActive)
            Text(displayLabel(for: sessionID))
                .font(.system(size: 12, weight: isGlobalActive ? .bold : (isPaneActive ? .semibold : .regular)))
                .foregroundStyle(isGlobalActive ? Color.white : Color.primary)
            Button {
                closeTab(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isGlobalActive ? Color.white.opacity(0.85) : Color.secondary)
                    // X の見た目は 9pt のまま、frame + contentShape で tap 受付エリアを 20×20 に広げる
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
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
            registry.setActiveTab(paneID: pane.id, tabIndex: index)
        }
        .draggable(sessionID)
    }

    /// タブアイコン。Claude ツールは猫耳画像、それ以外は SF Symbol。
    @ViewBuilder
    private func tabIcon(sessionID: SessionID, isGlobalActive: Bool) -> some View {
        if sessionID.tool == .claude {
            let tintColor = companionTintColor(for: sessionID)
            Image("cat-ear-tab")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(isGlobalActive ? Color.white : tintColor)
        } else {
            Image(systemName: sessionID.tool.systemImageName)
                .font(.system(size: 11, weight: isGlobalActive ? .bold : .regular))
                .foregroundStyle(isGlobalActive ? Color.white : Color.secondary)
        }
    }

    /// Claude セッションに紐付くコンパニオンのテーマカラーを返す
    private func companionTintColor(for sessionID: SessionID) -> Color {
        // CompanionStore からコンパニオンのアイコン名を取得
        for (companionID, sid) in companionStore.activeSessionMap where sid == sessionID {
            if let companion = companionStore.companions.first(where: { $0.id == companionID }),
               let rgb = CompanionIconPresets.themeColors[companion.icon] {
                return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
            }
        }
        return Color.secondary
    }

    /// タブヘッダの表示名。
    /// - Preview: state.title があればそれ、なければ URL の lastPathComponent、どちらも無ければ "Preview"
    /// - その他: tool 名 + (instance > 0 のとき番号)
    private func displayLabel(for sessionID: SessionID) -> String {
        if sessionID.tool == .preview,
           let s = registry.session(for: sessionID),
           let preview = s.state as? PreviewSessionState {
            if let title = preview.title, !title.isEmpty { return title }
            if let url = preview.url { return url.lastPathComponent }
        }
        if sessionID.tool == .gitDiff {
            return "Diff"
        }
        if sessionID.tool == .claude,
           let name = companionStore.companionName(for: sessionID) {
            return name
        }
        if sessionID.instance == 0 { return sessionID.tool.displayName }
        return "\(sessionID.tool.displayName) \(sessionID.instance + 1)"
    }

    /// 追加メニュー (+) ボタン。クリックで `showToolPickerMenu` を呼び、
    /// Cmd+T と完全に同じ NSMenu を「+」直下にポップアップ表示する。
    private var addButton: some View {
        Button {
            let point = tabPickerAnchor.bottomRightScreenPoint(for: pane.id) ?? NSEvent.mouseLocation
            Self.showToolPickerMenu(at: point, pane: pane, layout: layout, registry: registry)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11))
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AddButtonAnchorView(paneID: pane.id, anchor: tabPickerAnchor))
    }

    /// 指定 tool が追加可能か (PaneView の `+` メニューと AideaApp の Cmd+T で共用)。
    /// シングルトン Tool はアプリ全体で 1 つだけ。`gitDiff` は Git ツール経由でしか開かない。
    static func isAddable(_ tool: Tool, layout: LayoutConfig) -> Bool {
        let singletons: Set<Tool> = [.filer, .git, .kit]
        if singletons.contains(tool) {
            return !layout.allPanes.contains { pane in
                pane.tabs.contains { $0.tool == tool }
            }
        }
        if tool == .gitDiff { return false }
        return true
    }

    /// `+` メニュー / Cmd+T で表示する追加可能ツール一覧
    static func availableTools(layout: LayoutConfig) -> [Tool] {
        Tool.allCases.filter { isAddable($0, layout: layout) }
    }

    /// 新しい Session を生成して指定 Pane に追加し、active タブにする。
    /// PaneView の `+` メニューと AideaApp の Cmd+T で共用する。
    static func addSession(tool: Tool, to pane: Pane, layout: LayoutConfig, registry: SessionRegistry) {
        let instance = layout.nextSessionInstance(of: tool)
        let _ = registry.createSession(tool: tool, instance: instance)
        let id = SessionID(tool, instance: instance)
        pane.tabs.append(id)
        registry.setActiveTab(paneID: pane.id, tabIndex: pane.tabs.count - 1)
    }

    /// 指定 Pane 用のツール選択 NSMenu を screen 座標 `point` の左上に popUp 表示する。
    /// `+` ボタンの action と AideaApp の Cmd+T 双方から呼ばれ、見た目・項目・挙動を完全一致させる。
    static func showToolPickerMenu(at point: NSPoint, pane: Pane, layout: LayoutConfig, registry: SessionRegistry) {
        let menu = NSMenu()
        for tool in availableTools(layout: layout) {
            let item = ClosureMenuItem(
                title: tool.displayName,
                image: NSImage(systemSymbolName: tool.systemImageName, accessibilityDescription: nil)
            ) {
                addSession(tool: tool, to: pane, layout: layout, registry: registry)
            }
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: point, in: nil)
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

    /// タブをクローズ。全タブが閉じられた場合、このペイン自体をレイアウトツリーから取り除く。
    private func closeTab(at index: Int) {
        guard index >= 0, index < pane.tabs.count else { return }
        let closed = pane.tabs[index]
        pane.tabs.remove(at: index)
        companionStore.unbindSession(closed)
        registry.destroySession(closed)
        if pane.activeIndex >= pane.tabs.count {
            pane.activeIndex = max(0, pane.tabs.count - 1)
        }
        // 現在のペインがアクティブなら新しいアクティブタブに切替
        if registry.activePaneID == pane.id {
            registry.setActiveTab(paneID: pane.id, tabIndex: pane.activeIndex)
        }
        // 全タブが閉じられたらペイン自体を削除
        if pane.tabs.isEmpty {
            let node = layoutNode
            let lay = layout
            let reg = registry
            DispatchQueue.main.async {
                lay.removeLeaf(node)
                if let firstPane = lay.allPanes.first {
                    reg.setActiveTab(paneID: firstPane.id, tabIndex: firstPane.activeIndex)
                }
            }
        }
    }
}
