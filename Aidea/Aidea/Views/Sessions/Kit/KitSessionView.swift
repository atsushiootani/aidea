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
        .onAppear {
            reloadAll()
            if registry.activeSessionID == sessionID { isFocused = true }
        }
        .onChange(of: workspace.projectRoot) { _, _ in reloadAll() }
        .onChange(of: registry.activeSessionID) { _, newValue in
            if newValue == sessionID { isFocused = true }
        }
    }

    // MARK: - Data reload

    /// 全 Loader を projectRoot で再読み込み
    private func reloadAll() {
        state.agentsLoader.reload(projectRoot: workspace.projectRoot)
        state.skillsLoader.reload(projectRoot: workspace.projectRoot)
        state.commandsLoader.reload(projectRoot: workspace.projectRoot)
        state.mcpLoader.reload()
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

    /// セクションヘッダー (pinned 表示)。クリックで折りたたみトグル
    @ViewBuilder
    private func sectionHeader(_ kind: KitSection, count: Int) -> some View {
        let expanded = state.expandedSections.contains(kind)
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
            Text(kind.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
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

    /// サブグループヘッダー (三角形 + タイトル)
    @ViewBuilder
    private func subGroupHeader(title: String, expanded: Bool, key: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .padding(.leading, 16)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
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
        .onTapGesture(count: 2) {
            if let url = openPath {
                // openPreview のペイン決定ロジックは activeSessionID を起点にするので
                // 先に自分 (Kit) をアクティブに設定しておく
                registry.activeSessionID = sessionID
                registry.openPreview(for: url, title: name)
            }
        }
        .simultaneousGesture(
            TapGesture(count: 1).onEnded {
                state.selection = tag
                registry.activeSessionID = sessionID
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
