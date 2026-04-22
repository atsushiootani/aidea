//
//  KitSessionView.swift
//  Aidea
//

import SwiftUI

/// Kit Session の SwiftUI View。
/// 4 セクション (Agents / Skills / Commands / MCP Servers) をアコーディオン表示する。
/// スクロール時もセクションヘッダーを常に可視化するため、`LazyVStack` + `pinnedViews` を使う。
struct KitSessionView: View {
    @Bindable var state: KitSessionState
    let sessionID: SessionID
    @Environment(WorkspaceState.self) private var workspace
    @Environment(SessionRegistry.self) private var registry
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        if state.expandedSections.contains(.agents) {
                            ForEach(state.agentsLoader.agents) { agent in
                                row(
                                    name: agent.name,
                                    status: "inherit",
                                    scope: agent.scope,
                                    tag: "agents:\(agent.id)",
                                    indent: 16,
                                    openPath: agent.path
                                )
                            }
                        }
                    } header: {
                        sectionHeader(.agents, count: state.agentsLoader.agents.count)
                    }

                    sectionDivider

                    Section {
                        if state.expandedSections.contains(.skills) {
                            ForEach(groupedSkills, id: \.key) { group in
                                skillGroup(group: group)
                            }
                        }
                    } header: {
                        sectionHeader(.skills, count: state.skillsLoader.skills.count)
                    }

                    sectionDivider

                    Section {
                        if state.expandedSections.contains(.commands) {
                            ForEach(groupedCommands, id: \.key) { group in
                                commandGroup(group: group)
                            }
                        }
                    } header: {
                        sectionHeader(.commands, count: state.commandsLoader.commands.count)
                    }

                    sectionDivider

                    Section {
                        if state.expandedSections.contains(.mcps) {
                            ForEach(state.mcpLoader.servers) { server in
                                row(
                                    name: server.name,
                                    status: "configured",
                                    scope: .user,
                                    tag: "mcps:\(server.id)",
                                    indent: 16,
                                    openPath: nil
                                )
                            }
                        }
                    } header: {
                        sectionHeader(.mcps, count: state.mcpLoader.servers.count)
                    }
                }
            }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            // 上下キー: visibleTags を走査して選択項目を移動 + 必要に応じて自動スクロール
            .onKeyPress(.upArrow) {
                moveSelection(by: -1)
                scrollToSelection(proxy: proxy)
                return .handled
            }
            .onKeyPress(.downArrow) {
                moveSelection(by: 1)
                scrollToSelection(proxy: proxy)
                return .handled
            }
            // 左キー (VSCode 風):
            //  - 展開中の section/group: 閉じる
            //  - 折りたたみ中の group or 行: 親 (section/group) に移動
            //  - 折りたたみ中の section: no-op (親なし)
            .onKeyPress(.leftArrow) {
                handleLeftArrow()
                scrollToSelection(proxy: proxy)
                return .handled
            }
            // 右キー (VSCode 風):
            //  - 折りたたみ中の section/group: 開く
            //  - 展開中の section/group: 最初の子に移動
            //  - 行: no-op (葉)
            .onKeyPress(.rightArrow) {
                handleRightArrow()
                scrollToSelection(proxy: proxy)
                return .handled
            }
            // Enter: 選択行が openPath を持てば Preview を開く
            .onKeyPress(.return) {
                openCurrent()
                return .handled
            }
            // Space: 選択中が section/group なら展開トグル
            .onKeyPress(.space) {
                toggleFoldCurrent()
                return .handled
            }
            // Tab: SwiftUI の標準 focus nav を止める (Git/GitDiff 等へのフォーカス漏れ防止)
            .onKeyPress(.tab) { .handled }
            .onAppear {
                state.ensureWatcherStarted()
                state.reloadAll()
                if state.isActive { isFocused = true }
            }
            .onChange(of: workspace.projectRoot) { _, _ in
                state.ensureWatcherStarted()
                state.reloadAll()
            }
            .onChange(of: state.isActive) { _, active in
                if active { isFocused = true }
            }
        }
    }

    /// 現在の state.selection を ScrollViewReader proxy で表示範囲に収める。
    /// anchor: nil = 最小限のスクロール (既に可視なら no-op)。
    private func scrollToSelection(proxy: ScrollViewProxy) {
        guard let tag = state.selection else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            proxy.scrollTo(tag, anchor: nil)
        }
    }

    // MARK: - Selection navigation

    /// 現在の展開状態で画面に見えている項目の tag を行順に並べた配列。
    /// セクションヘッダーやサブグループヘッダーも含め、上下キーで選択できる全項目を列挙する。
    ///
    /// tag 形式:
    /// - `section:<rawValue>` — セクションヘッダー (agents / skills / commands / mcps)
    /// - `group:<sectionName>.<prefix>` — サブグループヘッダー (skills / commands の中)
    /// - `agents:<id>` / `skills:<id>` / `commands:<id>` / `mcps:<id>` — 行
    private var visibleTags: [String] {
        var tags: [String] = []

        tags.append("section:agents")
        if state.expandedSections.contains(.agents) {
            tags += state.agentsLoader.agents.map { "agents:\($0.id)" }
        }

        tags.append("section:skills")
        if state.expandedSections.contains(.skills) {
            for group in groupedSkills {
                if group.items.count == 1, group.items[0].name == group.key {
                    tags.append("skills:\(group.items[0].id)")
                } else {
                    let groupKey = "skills.\(group.key)"
                    tags.append("group:\(groupKey)")
                    if state.expandedGroups.contains(groupKey) {
                        tags += group.items.map { "skills:\($0.id)" }
                    }
                }
            }
        }

        tags.append("section:commands")
        if state.expandedSections.contains(.commands) {
            for group in groupedCommands {
                if group.items.count == 1, group.items[0].name == group.key {
                    tags.append("commands:\(group.items[0].id)")
                } else {
                    let groupKey = "commands.\(group.key)"
                    tags.append("group:\(groupKey)")
                    if state.expandedGroups.contains(groupKey) {
                        tags += group.items.map { "commands:\($0.id)" }
                    }
                }
            }
        }

        tags.append("section:mcps")
        if state.expandedSections.contains(.mcps) {
            tags += state.mcpLoader.servers.map { "mcps:\($0.id)" }
        }

        return tags
    }

    /// 選択位置を offset 分だけ動かす (上下キー用)。
    /// 選択なしの状態で ↓ なら先頭、↑ なら末尾を選ぶ。端を超える移動は端に留める。
    private func moveSelection(by offset: Int) {
        let tags = visibleTags
        guard !tags.isEmpty else { return }
        if let current = state.selection, let idx = tags.firstIndex(of: current) {
            let newIdx = max(0, min(tags.count - 1, idx + offset))
            state.selection = tags[newIdx]
        } else {
            state.selection = offset > 0 ? tags.first : tags.last
        }
    }

    /// 左キー (VSCode 風):
    /// - 展開中の section/group: 閉じる
    /// - 折りたたみ中の group または 行: 親項目 (section/group) に移動
    /// - 折りたたみ中の section: no-op (親がない)
    private func handleLeftArrow() {
        guard let tag = state.selection else { return }

        if tag.hasPrefix("section:") {
            let raw = String(tag.dropFirst("section:".count))
            if let kind = KitSection(rawValue: raw), state.expandedSections.contains(kind) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    state.expandedSections.remove(kind)
                }
            }
        } else if tag.hasPrefix("group:") {
            let key = String(tag.dropFirst("group:".count))
            if state.expandedGroups.contains(key) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    state.expandedGroups.remove(key)
                }
            } else if let parent = parentTag(of: tag) {
                state.selection = parent
            }
        } else {
            // 行: 親に移動
            if let parent = parentTag(of: tag) {
                state.selection = parent
            }
        }
    }

    /// 右キー (VSCode 風):
    /// - 折りたたみ中の section/group: 開く
    /// - 展開中の section/group: 最初の子に移動
    /// - 行: no-op (葉)
    private func handleRightArrow() {
        guard let tag = state.selection else { return }

        if tag.hasPrefix("section:") {
            let raw = String(tag.dropFirst("section:".count))
            if let kind = KitSection(rawValue: raw) {
                if !state.expandedSections.contains(kind) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.expandedSections.insert(kind)
                    }
                } else if let first = firstChildTag(of: tag) {
                    state.selection = first
                }
            }
        } else if tag.hasPrefix("group:") {
            let key = String(tag.dropFirst("group:".count))
            if !state.expandedGroups.contains(key) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    state.expandedGroups.insert(key)
                }
            } else if let first = firstChildTag(of: tag) {
                state.selection = first
            }
        }
        // 行: no-op
    }

    /// Space キー: 選択中が section/group なら展開トグル。行は no-op。
    private func toggleFoldCurrent() {
        guard let tag = state.selection else { return }
        if tag.hasPrefix("section:") {
            let raw = String(tag.dropFirst("section:".count))
            if let kind = KitSection(rawValue: raw) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if state.expandedSections.contains(kind) {
                        state.expandedSections.remove(kind)
                    } else {
                        state.expandedSections.insert(kind)
                    }
                }
            }
        } else if tag.hasPrefix("group:") {
            let key = String(tag.dropFirst("group:".count))
            withAnimation(.easeInOut(duration: 0.15)) {
                if state.expandedGroups.contains(key) {
                    state.expandedGroups.remove(key)
                } else {
                    state.expandedGroups.insert(key)
                }
            }
        }
    }

    /// Enter キー: 選択行が Preview で開けるパスを持てば Preview を開く。
    /// section/group や openPath なしの行 (mcps 等) は no-op。
    private func openCurrent() {
        guard let tag = state.selection else { return }
        if tag.hasPrefix("agents:") {
            let id = String(tag.dropFirst("agents:".count))
            if let agent = state.agentsLoader.agents.first(where: { $0.id == id }) {
                registry.openPreview(for: agent.path, title: agent.name)
            }
        } else if tag.hasPrefix("skills:") {
            let id = String(tag.dropFirst("skills:".count))
            if let skill = state.skillsLoader.skills.first(where: { $0.id == id }) {
                registry.openPreview(for: skill.path, title: skill.name)
            }
        } else if tag.hasPrefix("commands:") {
            let id = String(tag.dropFirst("commands:".count))
            if let cmd = state.commandsLoader.commands.first(where: { $0.id == id }) {
                registry.openPreview(for: cmd.path, title: cmd.name)
            }
        }
        // mcps / section / group: openPath なしなので no-op
    }

    /// 指定 tag の親 (直前の section/group tag) を返す。
    /// visibleTags を index から遡って最初に見つかった section/group を親とみなす。
    private func parentTag(of tag: String) -> String? {
        let tags = visibleTags
        guard let idx = tags.firstIndex(of: tag) else { return nil }
        for i in stride(from: idx - 1, through: 0, by: -1) {
            let t = tags[i]
            if t.hasPrefix("section:") || t.hasPrefix("group:") {
                return t
            }
        }
        return nil
    }

    /// 指定 tag の最初の子 (直後の tag) を返す。展開済 section/group で使う。
    private func firstChildTag(of tag: String) -> String? {
        let tags = visibleTags
        guard let idx = tags.firstIndex(of: tag), idx + 1 < tags.count else { return nil }
        return tags[idx + 1]
    }

    // MARK: - Grouping (Skills / Commands)

    /// Skill 一覧を `.`/`-` 前方一致でグループ化
    private var groupedSkills: [(key: String, items: [Skill])] {
        groupByPrefix(state.skillsLoader.skills) { $0.name }
    }

    /// Command 一覧を `.`/`-` 前方一致でグループ化
    private var groupedCommands: [(key: String, items: [Command])] {
        groupByPrefix(state.commandsLoader.commands) { $0.name }
    }

    /// 汎用: 名前の先頭プレフィクスでグループ化
    private func groupByPrefix<T>(_ items: [T], name: (T) -> String) -> [(key: String, items: [T])] {
        let dict = Dictionary(grouping: items) { item -> String in
            let n = name(item)
            let seps: Set<Character> = [".", "-"]
            if let idx = n.firstIndex(where: { seps.contains($0) }) {
                return String(n[..<idx])
            }
            return n
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.key < $1.key }
    }

    // MARK: - Section header (sticky)

    /// セクションヘッダー (pinned 表示)。クリックで折りたたみトグル + 選択設定。
    /// キーボード選択対象でもあり、選択中は行と同じアクセントカラーでハイライトする。
    @ViewBuilder
    private func sectionHeader(_ kind: KitSection, count: Int) -> some View {
        let expanded = state.expandedSections.contains(kind)
        let tag = "section:\(kind.rawValue)"
        let isSelected = (state.selection == tag)
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 9))
                .foregroundStyle(isSelected ? Color.white : .secondary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
            Text(kind.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isSelected ? Color.white : .secondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
        .contentShape(Rectangle())
        .id(tag)
        .onTapGesture {
            state.selection = tag
            withAnimation(.easeInOut(duration: 0.15)) {
                if expanded {
                    state.expandedSections.remove(kind)
                } else {
                    state.expandedSections.insert(kind)
                }
            }
        }
    }

    /// セクション間の区切り線
    private var sectionDivider: some View {
        Divider()
    }

    // MARK: - Sub-group (Skills / Commands)

    /// Skill のサブグループ (単独アイテム or 折りたたみグループ)
    @ViewBuilder
    private func skillGroup(group: (key: String, items: [Skill])) -> some View {
        if group.items.count == 1, group.items[0].name == group.key {
            let skill = group.items[0]
            row(
                name: skill.name,
                status: nil,
                scope: skill.scope,
                tag: "skills:\(skill.id)",
                indent: 16,
                openPath: skill.path
            )
        } else {
            let key = "skills.\(group.key)"
            let expanded = state.expandedGroups.contains(key)
            subGroupHeader(title: group.key, expanded: expanded, key: key)
            if expanded {
                ForEach(group.items) { skill in
                    row(
                        name: skill.name,
                        status: nil,
                        scope: skill.scope,
                        tag: "skills:\(skill.id)",
                        indent: 32,
                        openPath: skill.path
                    )
                }
            }
        }
    }

    /// Command のサブグループ (同上)
    @ViewBuilder
    private func commandGroup(group: (key: String, items: [Command])) -> some View {
        if group.items.count == 1, group.items[0].name == group.key {
            let cmd = group.items[0]
            row(
                name: cmd.name,
                status: nil,
                scope: cmd.scope,
                tag: "commands:\(cmd.id)",
                indent: 16,
                openPath: cmd.path
            )
        } else {
            let key = "commands.\(group.key)"
            let expanded = state.expandedGroups.contains(key)
            subGroupHeader(title: group.key, expanded: expanded, key: key)
            if expanded {
                ForEach(group.items) { cmd in
                    row(
                        name: cmd.name,
                        status: nil,
                        scope: cmd.scope,
                        tag: "commands:\(cmd.id)",
                        indent: 32,
                        openPath: cmd.path
                    )
                }
            }
        }
    }

    /// サブグループヘッダー (三角形 + タイトル)。
    /// キーボード選択対象でもあり、選択中はハイライトする。
    @ViewBuilder
    private func subGroupHeader(title: String, expanded: Bool, key: String) -> some View {
        let tag = "group:\(key)"
        let isSelected = (state.selection == tag)
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 9))
                .foregroundStyle(isSelected ? Color.white : .secondary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
            Spacer()
        }
        .padding(.leading, 16)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .id(tag)
        .onTapGesture {
            state.selection = tag
            withAnimation(.easeInOut(duration: 0.15)) {
                if expanded {
                    state.expandedGroups.remove(key)
                } else {
                    state.expandedGroups.insert(key)
                }
            }
        }
    }

    // MARK: - Row

    /// 1 行の表示 (名前 + status + scope)
    /// - Parameters:
    ///   - name: 表示名 (Preview タブのタイトルにも使う)
    ///   - openPath: ダブルクリックで Preview に開く URL (nil のとき無効)
    @ViewBuilder
    private func row(
        name: String,
        status: String?,
        scope: ResourceScope,
        tag: String,
        indent: CGFloat,
        openPath: URL?
    ) -> some View {
        let isSelected = (state.selection == tag)
        HStack(alignment: .center, spacing: 6) {
            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)
            Spacer()
            if let status = status {
                StatusTagView(text: status)
            }
            ScopeTagView(scope: scope)
        }
        .padding(.leading, indent)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .id(tag)
        .onTapGesture(count: 2) {
            if let url = openPath {
                // PaneView の simultaneousGesture が先に active を設定済み
                registry.openPreview(for: url, title: name)
            }
        }
        .simultaneousGesture(
            TapGesture(count: 1).onEnded {
                state.selection = tag
            }
        )
    }
}

/// ステータスバッジ (configured / inherit 等)
struct StatusTagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
            )
    }
}
