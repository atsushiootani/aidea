//
//  PaneView.swift
//  Aidea
//

import AppKit
import SwiftUI

/// 1 つの物理ペインを表す容器 View。複数の Tab (=Session への参照) をタブバーで切り替え、
/// 「+」ボタンで新しい Session を追加、「x」ボタンでタブを閉じることができる。
struct PaneView: View {
    @Bindable var pane: Pane
    /// このペインが属する LayoutNode。split / removeLeaf 操作で使う。
    let layoutNode: LayoutNode
    /// インラインリネーム編集中のタブ (仕様: ui-rules.md#タブのリネーム)
    @State private var renamingSessionID: SessionID?
    /// リネーム編集中のテキスト
    @State private var renameText: String = ""
    @Environment(SessionRegistry.self) private var registry
    @Environment(LayoutConfig.self) private var layout
    @Environment(CompanionStore.self) private var companionStore
    @Environment(TabPickerAnchor.self) private var tabPickerAnchor
    @Environment(WorkspaceState.self) private var workspace
    @FocusState private var renameFieldFocused: Bool

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
                        .environment(\.isTabVisible, isActive)
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
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        TabSlotView(pane: pane, index: 0)
                        ForEach(Array(pane.tabs.enumerated()), id: \.element) { index, sessionID in
                            tabItem(sessionID: sessionID, index: index)
                                .id(sessionID)
                            TabSlotView(pane: pane, index: index + 1)
                        }
                        addButton
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                }
                .onChange(of: pane.activeIndex) { _, newIndex in
                    guard newIndex < pane.tabs.count else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(pane.tabs[newIndex], anchor: .center)
                    }
                }
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
        let chip = HStack(spacing: 5) {
            tabIcon(sessionID: sessionID, isGlobalActive: isGlobalActive)
            if renamingSessionID == sessionID {
                // ダブルクリックでのインラインリネーム (仕様: ui-rules.md#タブのリネーム)
                TextField("", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(isGlobalActive ? Color.white : Color.primary)
                    .frame(width: 120)
                    .focused($renameFieldFocused)
                    .onSubmit { commitRename(for: sessionID) }
                    .onExitCommand { renamingSessionID = nil }
                    .onChange(of: renameFieldFocused) { _, focused in
                        // フォーカス喪失で確定 (Esc キャンセル時は renamingSessionID が先に nil になる)
                        if !focused { commitRename(for: sessionID) }
                    }
            } else {
                Text(displayLabel(for: sessionID))
                    .font(.system(size: 12, weight: isGlobalActive ? .bold : (isPaneActive ? .semibold : .regular)))
                    .foregroundStyle(isGlobalActive ? Color.white : Color.primary)
            }
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
        // ダブルクリックでリネーム開始。1 打目は上の onTapGesture が即時アクティブ化する
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            startRename(sessionID)
        })
        .draggable(sessionID)
        .help(previewTooltip(for: sessionID))
        return tabContextMenu(chip, sessionID: sessionID, index: index)
    }

    /// タブ種別ごとに右クリックメニューを付与する。メニューを持たないタブには付与しない (空メニューを出さない)。
    /// - Preview タブ (url あり): 仕様 docs/specs/tools/preview.md#タブ右クリックメニュー-issue-238
    /// - Claude タブ: 仕様 docs/specs/tools/claude.md#タブ右クリックメニュー
    /// - Filer タブ: 仕様 docs/specs/tools/filer.md#タブ右クリックメニュー-issue-270
    @ViewBuilder
    private func tabContextMenu<Content: View>(_ content: Content, sessionID: SessionID, index: Int) -> some View {
        if let url = previewURL(for: sessionID) {
            content.contextMenu {
                Button("タブ名を変更") { startRename(sessionID) }
                Divider()
                Button("リロード") { requestPreviewReload(sessionID) }
                Divider()
                Button("ファイル名をコピー") { copyToPasteboard(url.lastPathComponent) }
                Button("プロジェクト相対パスをコピー") { copyToPasteboard(previewTooltip(for: sessionID)) }
                Button("絶対パスをコピー") { copyToPasteboard(url.standardizedFileURL.path) }
                Divider()
                Button("ファイラで選択") { registry.revealInFiler(url) }
                Divider()
                Button("タブを閉じる") { closeTab(at: index) }
            }
        } else if sessionID.tool == .claude {
            content.contextMenu {
                Button("instruction読み込み") { sendInstructionLoad(sessionID) }
                    // Companion 未バインドの Claude タブは index を解決できないため無効化する
                    .disabled(companionStore.companion(for: sessionID)?.index == nil)
                Divider()
                Button("タブを閉じる") { closeTab(at: index) }
            }
        } else if sessionID.tool == .filer {
            content.contextMenu {
                Button("リロード") { requestFilerReload(sessionID) }
            }
        } else {
            content
        }
    }

    /// Claude タブの「instruction読み込み」: Companion 指示書を Claude Code の `@` ファイル参照記法で
    /// 再読み込みさせる。`@.aidea/claude/companions/<index>/instructions.md` を Frontchannel
    /// (`sendMessageWhenReady`) で送信する。`/clear` 後などに指示書を読み直させる用途。
    /// 仕様: docs/specs/tools/claude.md#タブ右クリックメニュー
    private func sendInstructionLoad(_ sessionID: SessionID) {
        guard let index = companionStore.companion(for: sessionID)?.index,
              let session = registry.session(for: sessionID),
              let claude = session.state as? ClaudeSessionState else { return }
        let path = "\(CompanionInstructions.baseDir)/\(index)/\(CompanionInstructions.entrypoint)"
        claude.sendMessageWhenReady("@\(path)")
    }

    /// Preview タブが指すファイル URL。Preview 以外・url 未設定なら nil。
    private func previewURL(for sessionID: SessionID) -> URL? {
        guard sessionID.tool == .preview,
              let s = registry.session(for: sessionID),
              let preview = s.state as? PreviewSessionState,
              let url = preview.url else { return nil }
        return url
    }

    /// Preview タブの表示中ファイルを手動リロードする (issue #241)。
    private func requestPreviewReload(_ sessionID: SessionID) {
        guard sessionID.tool == .preview,
              let s = registry.session(for: sessionID),
              let preview = s.state as? PreviewSessionState else { return }
        preview.requestReload()
    }

    /// Filer タブのツリー表示を手動リロードする (issue #270)。FSEvents の自動反映が
    /// 遅延・欠落するケースへのフォールバック。
    private func requestFilerReload(_ sessionID: SessionID) {
        guard sessionID.tool == .filer,
              let s = registry.session(for: sessionID),
              let filer = s.state as? FilerSessionState else { return }
        filer.controller.requestManualReload()
    }

    /// 文字列を一般ペーストボードにコピーする。
    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    /// タブ名のインライン編集を開始する。現在の表示名をプリセットしてフォーカスを移す
    private func startRename(_ sessionID: SessionID) {
        renameText = displayLabel(for: sessionID)
        renamingSessionID = sessionID
        DispatchQueue.main.async {
            renameFieldFocused = true
        }
    }

    /// 編集中のタブ名を確定する。空白のみの入力はカスタム名解除 (デフォルト導出名に戻る)
    private func commitRename(for sessionID: SessionID) {
        guard renamingSessionID == sessionID else { return }
        registry.setCustomTitle(renameText, for: sessionID)
        renamingSessionID = nil
    }

    /// Preview タブのツールチップテキスト。projectRoot 相対パスを返す。
    /// Preview 以外のタブや URL が nil の場合は空文字 (ツールチップなし)。
    private func previewTooltip(for sessionID: SessionID) -> String {
        guard sessionID.tool == .preview,
              let s = registry.session(for: sessionID),
              let preview = s.state as? PreviewSessionState,
              let url = preview.url else { return "" }
        if let root = workspace.projectRoot {
            let rootPath = root.standardizedFileURL.path
            let filePath = url.standardizedFileURL.path
            if filePath.hasPrefix(rootPath) {
                let relative = String(filePath.dropFirst(rootPath.count))
                return relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
            }
        }
        return url.path
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
        if let companion = companionStore.companions.first(where: { $0.sessionID == sessionID }),
           let rgb = CompanionIconPresets.themeColors[companion.icon] {
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        }
        return Color.secondary
    }

    /// タブヘッダの表示名。
    /// - カスタム名 (ダブルクリックでリネーム) があれば最優先
    /// - Preview: state.title があればそれ、なければ URL の lastPathComponent、どちらも無ければ "Preview"
    /// - Web: 現在の URL (scheme 除去 + 先頭 20 文字。仕様: docs/specs/tools/web.md#タブ名)
    /// - その他: tool 名 + (instance > 0 のとき番号)
    private func displayLabel(for sessionID: SessionID) -> String {
        if let custom = registry.customTitles[sessionID] {
            return custom
        }
        if sessionID.tool == .preview,
           let s = registry.session(for: sessionID),
           let preview = s.state as? PreviewSessionState {
            if let title = preview.title, !title.isEmpty { return title }
            if let url = preview.url { return url.lastPathComponent }
        }
        if sessionID.tool == .web,
           let s = registry.session(for: sessionID),
           let web = s.state as? WebSessionState {
            var label = web.url.absoluteString
            for prefix in ["https://", "http://"] where label.hasPrefix(prefix) {
                label.removeFirst(prefix.count)
            }
            return String(label.prefix(20))
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
    /// クローズ後のアクティブタブ選択は docs/specs/window/tab-bar.md#クローズ後のアクティブタブ選択-issue-253。
    private func closeTab(at index: Int) {
        guard index >= 0, index < pane.tabs.count else { return }
        let closed = pane.tabs[index]
        let wasActive = (pane.activeIndex == index)
        // 非アクティブタブを閉じた場合はアクティブタブを維持する (削除による index ずれを補正)
        let activeID: SessionID? = pane.activeIndex < pane.tabs.count ? pane.tabs[pane.activeIndex] : nil
        pane.tabs.remove(at: index)
        companionStore.unbindSession(closed)
        registry.destroySession(closed)
        if !pane.tabs.isEmpty {
            if wasActive {
                // アクティブタブを閉じた → ペイン内で最も最近アクティブだったタブへ (issue #253)。
                // 履歴に無ければ従来どおり隣接タブ (同 index、末尾なら 1 つ前)。
                pane.activeIndex = registry.mostRecentTabIndex(in: pane) ?? min(index, pane.tabs.count - 1)
            } else if let activeID, let idx = pane.tabs.firstIndex(of: activeID) {
                pane.activeIndex = idx
            } else if pane.activeIndex >= pane.tabs.count {
                pane.activeIndex = pane.tabs.count - 1
            }
        } else {
            pane.activeIndex = 0
        }
        // 現在のペインがアクティブなら新しいアクティブタブに切替
        if registry.activePaneID == pane.id, !pane.tabs.isEmpty {
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
