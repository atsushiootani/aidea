//
//  GitSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// Git Session の SwiftUI ラッパ。変更ファイル一覧を NSOutlineView で表示する。
struct GitSessionView: NSViewControllerRepresentable {
    let state: GitSessionState
    @Environment(WorkspaceState.self) private var workspace

    func makeNSViewController(context: Context) -> GitFileListViewController {
        let vc = GitFileListViewController()
        vc.state = state
        vc.loadViewIfNeeded()
        vc.reload()
        // bridge に NSView 参照を登録 (SwiftUI update cycle と分離)。
        // 契約 C1 (アクティブ化時フォーカス) と SessionRegistry の click-to-activate 両方の用途。
        let outlineView = vc.outlineView
        DispatchQueue.main.async { [state] in
            state.focusBridge.setView(outlineView)
        }
        return vc
    }

    func updateNSViewController(_ vc: GitFileListViewController, context: Context) {
        // モード変更時に再読み込み
    }
}

/// Tab キーで GitDiff にフォーカス移動する NSOutlineView サブクラス
final class GitOutlineView: NSOutlineView {
    var onTabPressed: (() -> Void)?
    var onModeChanged: ((GitMode) -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 {
            onTabPressed?()
            return
        }
        // Ctrl+4 = Working Changes, Ctrl+5 = PR Preview
        if event.modifierFlags.contains(.control) {
            if event.keyCode == 21 { onModeChanged?(.workingChanges); return }  // 4
            if event.keyCode == 23 { onModeChanged?(.prPreview); return }       // 5
        }
        // W = Working Changes, P = PR Preview (フォールバック)
        if let chars = event.charactersIgnoringModifiers?.lowercased(), !event.modifierFlags.contains(.command) {
            if chars == "w" { onModeChanged?(.workingChanges); return }
            if chars == "p" { onModeChanged?(.prPreview); return }
        }
        super.keyDown(with: event)
    }
}

/// Git 変更ファイル一覧の NSViewController
final class GitFileListViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var state: GitSessionState?
    let outlineView = GitOutlineView()
    private let scrollView = NSScrollView()
    private let branchBadge = BranchBadgeView()
    private var picker: NSSegmentedControl?
    private let watcher = FileWatcher()
    private var reloadWorkItem: DispatchWorkItem?
    /// Diff 追従による選択変更中は true（無限ループ防止）
    private var isUpdatingFromDiff = false

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Name"
        column.minWidth = 100
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.style = .plain
        outlineView.allowsMultipleSelection = false
        outlineView.indentationPerLevel = 14
        outlineView.target = self
        outlineView.doubleAction = #selector(handleDoubleClick)

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor

        // モード切替ピッカー
        let picker = NSSegmentedControl(labels: GitMode.allCases.map(\.rawValue),
                                        trackingMode: .selectOne,
                                        target: self,
                                        action: #selector(modeChanged(_:)))
        picker.selectedSegment = 0
        picker.segmentDistribution = .fillEqually
        picker.translatesAutoresizingMaskIntoConstraints = false
        self.picker = picker

        branchBadge.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(picker)
        container.addSubview(branchBadge)
        container.addSubview(scrollView)
        picker.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            picker.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            picker.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            branchBadge.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 4),
            branchBadge.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            branchBadge.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            branchBadge.heightAnchor.constraint(equalToConstant: 22),
            scrollView.topAnchor.constraint(equalTo: branchBadge.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        self.view = container

        // Tab キーで GitDiff にフォーカス移動。
        // SwiftUI の focus nav で他 Session から漏れて firstResponder が奪われたケースを弾くため、
        // activeSessionID が Git 自身かを確認してから発火する。
        outlineView.onTabPressed = { [weak self] in
            guard let self,
                  self.state?.registry?.activeSessionID?.tool == .git else { return }
            self.focusGitDiff()
        }

        // W / P キーでモード切替。同上、activeSessionID チェック付き。
        outlineView.onModeChanged = { [weak self] mode in
            guard let self,
                  self.state?.registry?.activeSessionID?.tool == .git else { return }
            self.state?.mode = mode
            self.picker?.selectedSegment = GitMode.allCases.firstIndex(of: mode) ?? 0
            self.reload()
            // GitDiff も連動
            self.switchDiffMode(mode)
        }


        // GitDiff のフォーカスファイル変化に追従して OutlineView の選択を更新
        state?.onSelectedPathChanged = { [weak self] path in
            guard let self, let path else { return }
            self.selectNode(withPath: path)
        }

        // Viewed 状態変化時に OutlineView をリロード
        state?.onViewedChanged = { [weak self] in
            self?.outlineView.reloadData()
            self?.outlineView.expandItem(nil, expandChildren: true)
        }

        // .git 監視で自動更新
        if let root = state?.workspace.projectRoot {
            let gitDir = root.appending(path: ".git").path
            watcher.start(path: gitDir) { [weak self] _ in
                self?.scheduleReload()
            }
        }
    }

    func reload() {
        state?.reload()
        updateBranchLabel()
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
    }

    /// モードに応じてブランチラベルと合計行数を更新する
    private func updateBranchLabel() {
        guard let state else { return }
        let totalAdded: Int
        let totalDeleted: Int
        switch state.mode {
        case .workingChanges:
            // staged + unstaged の合算 (同一ファイルが両方にある場合は両方をカウント)
            totalAdded = state.fileStats.values.reduce(0) { $0 + $1.added }
                + state.stagedFileStats.values.reduce(0) { $0 + $1.added }
            totalDeleted = state.fileStats.values.reduce(0) { $0 + $1.deleted }
                + state.stagedFileStats.values.reduce(0) { $0 + $1.deleted }
            branchBadge.setBranches([state.currentBranch], added: totalAdded, deleted: totalDeleted)
        case .prPreview:
            totalAdded = state.fileStats.values.reduce(0) { $0 + $1.added }
            totalDeleted = state.fileStats.values.reduce(0) { $0 + $1.deleted }
            branchBadge.setBranches([state.baseBranch, state.currentBranch], added: totalAdded, deleted: totalDeleted)
        }
    }

    private func scheduleReload() {
        reloadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reload()
        }
        reloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        state?.mode = GitMode.allCases[sender.selectedSegment]
        reload()
    }

    @objc private func handleDoubleClick() {
        let row = outlineView.clickedRow
        let filePath = (outlineView.item(atRow: row) as? GitFileTreeNode)?.relativePath
        guard let registry = state?.registry, let mode = state?.mode else { return }
        registry.openGitDiff(mode: mode, scrollToFile: filePath)
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return state?.treeNodes.count ?? 0 }
        return (item as? GitFileTreeNode)?.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? GitFileTreeNode {
            return node.children![index]
        }
        return state!.treeNodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? GitFileTreeNode)?.isDirectory ?? false
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? GitFileTreeNode else { return nil }
        let id = NSUserInterfaceItemIdentifier("GitCell2")
        let cell: GitFileCellView
        if let recycled = outlineView.makeView(withIdentifier: id, owner: self) as? GitFileCellView {
            cell = recycled
        } else {
            cell = GitFileCellView()
            cell.identifier = id
        }
        let isViewed = !node.isDirectory && isFileViewed(node.relativePath)
        let stat = node.isDirectory ? nil : fileStat(for: node.relativePath, isStaged: node.isStaged)
        let decoration = resolveDecoration(for: node)
        cell.configure(node: node, isViewed: isViewed, stat: stat, decorationIcon: decoration.icon)
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        guard let node = item as? GitFileTreeNode else { return nil }
        let decoration = resolveDecoration(for: node)
        let row = DecorationRowView()
        row.decorationBackground = DecorationColorPresets.appliedBackground(for: decoration.color)
        return row
    }

    /// Filer のデコレーションルール (default + user) を使い、Git ファイルノードの装飾を解決する。
    /// ディレクトリはユーザルールの色のみ、ファイルは default + user を合成する。
    private func resolveDecoration(for node: GitFileTreeNode) -> DecorationMatcher.Resolved {
        let filerState = state?.registry?.session(for: SessionID(.filer, instance: 0))?.state as? FilerSessionState
        let userRules = filerState?.userDecorationRules ?? []
        if node.isDirectory {
            let matcher = DecorationMatcher(defaults: [], userRules: userRules)
            return matcher.resolve(relativePath: node.relativePath)
        }
        let matcher = DecorationMatcher(
            defaults: FilerSessionState.defaultDecorationRules,
            userRules: userRules
        )
        return matcher.resolve(relativePath: node.relativePath)
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isUpdatingFromDiff else { return }
        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? GitFileTreeNode, !node.isDirectory else { return }
        state?.selectedPath = node.relativePath
        // 既に開いている GitDiff があればそのファイルにジャンプ
        scrollDiffToFile(node.relativePath)
    }

    /// ファイルの追加/削除行数を返す
    /// Working Changes: staged ノードは stagedFileStats、unstaged ノードは fileStats を参照
    private func fileStat(for path: String, isStaged: Bool) -> (added: Int, deleted: Int)? {
        guard let state else { return nil }
        if isStaged && state.mode == .workingChanges {
            return state.stagedFileStats[path]
        }
        return state.fileStats[path]
    }

    /// ファイルが Viewed かどうかを GitDiff の viewedFiles から判定する
    private func isFileViewed(_ path: String) -> Bool {
        guard let registry = state?.registry else { return false }
        for pane in registry.layout.allPanes {
            for id in pane.tabs where id.tool == .gitDiff {
                if let s = registry.session(for: id),
                   let diffState = s.state as? GitDiffSessionState {
                    return diffState.viewedFiles.contains { $0.contains(path) || path.contains($0) }
                }
            }
        }
        return false
    }

    /// ファイルパスに一致する行を OutlineView で選択する（Diff からの追従用）
    private func selectNode(withPath path: String) {
        isUpdatingFromDiff = true
        for row in 0..<outlineView.numberOfRows {
            if let node = outlineView.item(atRow: row) as? GitFileTreeNode,
               !node.isDirectory,
               path.contains(node.relativePath) || node.relativePath.contains(path) {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                outlineView.scrollRowToVisible(row)
                break
            }
        }
        isUpdatingFromDiff = false
    }


    /// GitDiff のモードを切り替える
    private func switchDiffMode(_ mode: GitMode) {
        guard let registry = state?.registry else { return }
        for pane in registry.layout.allPanes {
            for id in pane.tabs where id.tool == .gitDiff {
                if let s = registry.session(for: id),
                   let diffState = s.state as? GitDiffSessionState {
                    diffState.mode = mode
                    diffState.reload()
                    return
                }
            }
        }
    }

    /// GitDiff セッションにフォーカスを移す
    private func focusGitDiff() {
        guard let registry = state?.registry, let mode = state?.mode else { return }
        // GitDiff が無ければ開く
        registry.openGitDiff(mode: mode, scrollToFile: state?.selectedPath)
    }

    /// 既存の GitDiff セッションにスクロール指示を送る
    private func scrollDiffToFile(_ filePath: String) {
        guard let registry = state?.registry else { return }
        for pane in registry.layout.allPanes {
            for id in pane.tabs where id.tool == .gitDiff {
                if let s = registry.session(for: id),
                   let diffState = s.state as? GitDiffSessionState {
                    diffState.scrollToFile = filePath
                    return
                }
            }
        }
    }
}

/// Git ファイル一覧のセル。左にアイコン+ファイル名、右に行数統計+✅マーク。
final class GitFileCellView: NSTableCellView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let statLabel = NSTextField(labelWithString: "")
    private let viewedLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        icon.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingMiddle
        statLabel.translatesAutoresizingMaskIntoConstraints = false
        statLabel.alignment = .right
        statLabel.setContentHuggingPriority(.required, for: .horizontal)
        statLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        viewedLabel.translatesAutoresizingMaskIntoConstraints = false
        viewedLabel.setContentHuggingPriority(.required, for: .horizontal)
        viewedLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(icon)
        addSubview(label)
        addSubview(statLabel)
        addSubview(viewedLabel)
        imageView = icon
        textField = label

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            statLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 6),
            statLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            viewedLabel.leadingAnchor.constraint(equalTo: statLabel.trailingAnchor, constant: 4),
            viewedLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            viewedLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(node: GitFileTreeNode, isViewed: Bool, stat: (added: Int, deleted: Int)?, decorationIcon: String?) {
        label.stringValue = node.name
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        if node.isDirectory {
            icon.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
            icon.contentTintColor = .secondaryLabelColor
            statLabel.stringValue = ""
            viewedLabel.stringValue = ""
        } else if let status = node.status {
            // ファイル種別アイコン (decoration 解決済み) を優先し、マッチなしならステータスアイコンにフォールバック
            let iconName = decorationIcon ?? status.iconName
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
                ?? NSImage(named: iconName)
            icon.image = image
            icon.contentTintColor = .labelColor

            // 行数統計
            if let stat {
                let statStr = NSMutableAttributedString()
                statStr.append(NSAttributedString(string: "+\(stat.added)", attributes: [
                    .foregroundColor: NSColor.systemGreen,
                    .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                ]))
                statStr.append(NSAttributedString(string: " -\(stat.deleted)", attributes: [
                    .foregroundColor: NSColor.systemRed,
                    .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                ]))
                statLabel.attributedStringValue = statStr
            } else {
                statLabel.stringValue = ""
            }

            viewedLabel.stringValue = isViewed ? "✅" : ""
        }
    }
}

/// ブランチ名を角丸四角形の塗りつぶし背景で表示するバッジ。
/// 複数ブランチの場合は ".." で区切って個別のバッジを表示する。
final class BranchBadgeView: NSView {
    private let stack = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    /// ブランチ名を設定する。1つなら単独バッジ、2つなら ".." 区切りで2バッジ。
    func setBranches(_ branches: [String], added: Int = 0, deleted: Int = 0) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, branch) in branches.enumerated() {
            if i > 0 {
                let separator = NSTextField(labelWithString: "..")
                separator.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
                separator.textColor = .secondaryLabelColor
                stack.addArrangedSubview(separator)
            }
            stack.addArrangedSubview(makeBadge(branch))
        }
        if added > 0 || deleted > 0 {
            // スペーサーで右寄せ
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            stack.addArrangedSubview(spacer)
            stack.addArrangedSubview(makeStatLabel(added: added, deleted: deleted))
        }
    }

    private func makeStatLabel(added: Int, deleted: Int) -> NSView {
        let label = NSTextField(labelWithString: "")
        let str = NSMutableAttributedString()
        str.append(NSAttributedString(string: "+\(added)", attributes: [
            .foregroundColor: NSColor.systemGreen,
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
        ]))
        str.append(NSAttributedString(string: " -\(deleted)", attributes: [
            .foregroundColor: NSColor.systemRed,
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
        ]))
        label.attributedStringValue = str
        return label
    }

    private func makeBadge(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail

        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 4
        badge.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.15).cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badge.heightAnchor.constraint(equalToConstant: 20),
        ])
        return badge
    }
}
