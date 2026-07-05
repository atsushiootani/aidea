//
//  FilerSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Filer Session の SwiftUI ラッパ。FilerSessionState が保持する NSViewController を再利用する。
struct FilerSessionView: NSViewControllerRepresentable {
    let state: FilerSessionState
    @Environment(WorkspaceState.self) private var workspace

    func makeNSViewController(context: Context) -> FileTreeViewController {
        state.controller.workspace = workspace
        state.controller.loadViewIfNeeded()
        state.controller.reload()
        let outlineView = state.controller.outlineView
        // bridge に NSView 参照を登録 (SwiftUI update cycle と分離)。
        // 契約 C1 (アクティブ化時フォーカス) と SessionRegistry の click-to-activate 両方の用途。
        DispatchQueue.main.async {
            state.focusBridge.setView(outlineView)
        }
        return state.controller
    }

    func updateNSViewController(_ vc: FileTreeViewController, context: Context) {
        let effectiveRoot = state.customRoot ?? workspace.projectRoot
        if vc.currentRoot != effectiveRoot {
            vc.reload()
        }
    }
}

/// NSOutlineView を保持する NSViewController。データソース・デリゲート・ファイル監視を兼ねる。
final class FileTreeViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSSearchFieldDelegate {
    var workspace: WorkspaceState?
    /// この Controller を所有する FilerSessionState (選択ファイルの書き戻し先)
    weak var owner: FilerSessionState?
    /// 現在表示中のルート (差分検知用)
    var currentRoot: URL?

    /// NSOutlineView 本体。外部から First Responder にするためのアクセス用に internal。
    let outlineView = FilerOutlineView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    // MARK: - Navigate Bar
    private let navigateBar = NSStackView()
    private let backToProjectButton = NSButton()
    private let rootSelectorButton = NSButton()
    private let watcher = FileWatcher()
    private var rootNodes: [FileTreeNode] = []
    private var reloadWorkItem: DispatchWorkItem?

    // MARK: - Directory Summary (issue #193)
    /// ディレクトリ要約の永続ストア (.aidea/state/dir-summaries.json)。reload() で張り替える
    private var summaryStore: DirectorySummaryStore?
    /// 要約生成中の URL 集合 (多重リクエスト防止)
    private var summaryInFlight: Set<URL> = []

    /// owner (FilerSessionState) の除外ルールから ExcludeMatcher を組み立てる。
    /// owner が未設定なら defaultExcludeRules を使う。
    private func excludeMatcher() -> ExcludeMatcher {
        ExcludeMatcher(patterns: owner?.excludeRules ?? FilerSessionState.defaultExcludeRules)
    }

    /// 指定ディレクトリの直下をロードし、除外ルールに該当するエントリをフィルタする。
    /// 親がシンボリックリンクで、解決先が祖先チェーン内に既に出現する場合は循環とみなして空配列を返す (issue #119)。
    private func loadAndFilter(directory url: URL, parent: FileTreeNode? = nil) -> [FileTreeNode] {
        if let parent, parent.isSymbolicLink, Self.formsSymlinkCycle(at: parent) {
            return []
        }
        let nodes = FileTreeLoader.load(directory: url, parent: parent)
        guard let root = currentRoot else { return nodes }
        let matcher = excludeMatcher()
        return nodes.filter { node in
            let relative = Self.relativePath(of: node.url, from: root)
            return !matcher.matches(relativePath: relative)
        }
    }

    /// シンボリックリンクの循環判定 (issue #119)。
    /// `node` の解決先パスが、自身の祖先チェーン内のいずれかのノードの解決先と一致したら循環。
    private static func formsSymlinkCycle(at node: FileTreeNode) -> Bool {
        let target = node.url.resolvingSymlinksInPath().standardizedFileURL.path
        var ancestor = node.parent
        while let current = ancestor {
            let ancestorPath = current.url.resolvingSymlinksInPath().standardizedFileURL.path
            if ancestorPath == target { return true }
            ancestor = current.parent
        }
        return false
    }

    /// projectRoot からの相対パスを返す (先頭スラッシュ無し)。root 配下でない場合は basename にフォールバック。
    private static func relativePath(of url: URL, from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let nodePath = url.standardizedFileURL.path
        guard nodePath.hasPrefix(rootPath) else { return url.lastPathComponent }
        let suffix = String(nodePath.dropFirst(rootPath.count))
        return suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // 検索関連の状態
    private var searchQuery: String = ""
    private var filteredRoots: [FileTreeNode] = []
    /// 検索中のフィルタ済み子ノード (ObjectIdentifier をキーに)
    private var filteredChildren: [ObjectIdentifier: [FileTreeNode]] = [:]

    /// 検索中か
    private var isSearching: Bool { !searchQuery.isEmpty }

    // MARK: - Navigate Bar Setup

    private func buildNavigateBar() {
        backToProjectButton.title = "← Project"
        backToProjectButton.bezelStyle = .inline
        backToProjectButton.isBordered = false
        backToProjectButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        backToProjectButton.contentTintColor = .secondaryLabelColor
        backToProjectButton.target = self
        backToProjectButton.action = #selector(backToProjectAction)
        backToProjectButton.isHidden = true

        rootSelectorButton.bezelStyle = .inline
        rootSelectorButton.isBordered = false
        rootSelectorButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        rootSelectorButton.contentTintColor = .labelColor
        rootSelectorButton.target = self
        rootSelectorButton.action = #selector(showNavigateMenu)

        navigateBar.orientation = .horizontal
        navigateBar.spacing = 4
        navigateBar.alignment = .centerY
        navigateBar.addArrangedSubview(backToProjectButton)
        navigateBar.addArrangedSubview(rootSelectorButton)

        backToProjectButton.setContentHuggingPriority(.required, for: .horizontal)
        rootSelectorButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    @objc private func backToProjectAction() {
        navigateToRoot(nil)
    }

    @objc private func showNavigateMenu() {
        let menu = buildNavigateMenu()
        let bounds = rootSelectorButton.bounds
        menu.popUp(positioning: nil, at: NSPoint(x: bounds.minX, y: bounds.maxY), in: rootSelectorButton)
    }

    /// Cmd+Shift+G キーボードショートカット経由でナビゲーションメニューを表示する
    func showNavigateMenuFromKeyboard() {
        let menu = buildNavigateMenu()
        let bounds = rootSelectorButton.bounds
        menu.popUp(positioning: nil, at: NSPoint(x: bounds.minX, y: bounds.maxY), in: rootSelectorButton)
    }

    private func buildNavigateMenu() -> NSMenu {
        let menu = NSMenu()
        let projectRoot = workspace?.projectRoot
        let effectiveRoot = owner?.customRoot ?? projectRoot

        let projectTitle = projectRoot?.lastPathComponent ?? "Project"
        let projectItem = ClosureMenuItem(title: projectTitle, image: NSImage(systemSymbolName: "folder", accessibilityDescription: nil)) { [weak self] in
            self?.navigateToRoot(nil)
        }
        projectItem.state = (effectiveRoot == projectRoot) ? .on : .off
        menu.addItem(projectItem)

        menu.addItem(NSMenuItem.separator())

        let systemDirs: [(String, String)] = [
            ("Downloads", "arrow.down.circle"),
            ("Desktop", "menubar.dock.rectangle"),
            ("Pictures", "photo.on.rectangle")
        ]
        let home = FileManager.default.homeDirectoryForCurrentUser
        for (name, symbol) in systemDirs {
            let url = home.appendingPathComponent(name)
            let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            let item = ClosureMenuItem(title: name, image: icon) { [weak self] in
                self?.navigateToRoot(url)
            }
            item.state = (effectiveRoot == url) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let openItem = ClosureMenuItem(title: "フォルダを開く...", image: NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)) { [weak self] in
            self?.openFolderPanel()
        }
        menu.addItem(openItem)

        return menu
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "表示するフォルダを選択"
        if panel.runModal() == .OK, let url = panel.url {
            navigateToRoot(url)
        }
    }

    /// ルートを切り替えてリロードする。nil を渡すとプロジェクトルートに戻る。
    func navigateToRoot(_ url: URL?) {
        owner?.customRoot = url
        reload()
    }

    private func updateNavigateBar() {
        let isAtProjectRoot = (owner?.customRoot == nil)
        backToProjectButton.isHidden = isAtProjectRoot
        let name = currentRoot?.lastPathComponent ?? workspace?.projectRoot?.lastPathComponent ?? "Filer"
        rootSelectorButton.title = name + " ▾"
    }

    /// View 階層を構築する
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
        outlineView.allowsMultipleSelection = true
        outlineView.indentationPerLevel = 14
        // キーボードイベントをこのコントローラに委譲
        outlineView.controller = self
        // ドラッグ&ドロップ: ファイル URL の並び替え/移動を受け付ける
        // .copy を許可する理由: SwiftUI 側の TabSlotView `.dropDestination(for: URL.self)` は
        // デフォルトで .copy 操作を期待するため。Filer 内ドロップは acceptDrop が .move を返すので
        // 実際の操作は引き続き move として解決される。
        outlineView.registerForDraggedTypes([.fileURL])
        outlineView.setDraggingSourceOperationMask([.move, .copy], forLocal: true)
        outlineView.setDraggingSourceOperationMask([.move, .copy], forLocal: false)
        // ダブルクリックで Preview Session を新規作成
        outlineView.target = self
        outlineView.doubleAction = #selector(handleDoubleClick)

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor

        // 検索フィールド (非表示で開始)
        searchField.placeholderString = "ファイル名を検索"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        searchField.isHidden = true

        buildNavigateBar()

        let stack = NSStackView(views: [navigateBar, searchField, scrollView])
        stack.orientation = .vertical
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        stack.distribution = .fill
        navigateBar.setContentHuggingPriority(.required, for: .vertical)
        searchField.setContentHuggingPriority(.required, for: .vertical)
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        self.view = stack
    }

    // MARK: - Search

    /// Cmd+F で呼ばれる: 検索バーの表示をトグル
    func toggleSearchBar() {
        if searchField.isHidden {
            searchField.isHidden = false
            searchField.stringValue = ""
            view.window?.makeFirstResponder(searchField)
        } else {
            closeSearchBar()
        }
    }

    /// 検索バーを閉じて通常表示に戻す
    private func closeSearchBar() {
        searchField.stringValue = ""
        searchField.isHidden = true
        applySearch("")
        view.window?.makeFirstResponder(outlineView)
    }

    /// 検索バーが開いていれば閉じて true を返す。そうでなければ false。
    /// FilerOutlineView の Esc ハンドラから呼ばれる。
    func closeSearchBarIfOpen() -> Bool {
        if !searchField.isHidden {
            closeSearchBar()
            return true
        }
        return false
    }

    /// 検索フィールドの入力が変わったときに呼ばれる
    @objc private func searchFieldChanged() {
        applySearch(searchField.stringValue)
    }

    /// フィルタを適用して outlineView を更新する
    private func applySearch(_ query: String) {
        searchQuery = query.trimmingCharacters(in: .whitespaces)
        filteredChildren = [:]
        filteredRoots = []

        if !searchQuery.isEmpty {
            let lower = searchQuery.lowercased()
            for root in rootNodes {
                if walkForSearch(node: root, query: lower) {
                    filteredRoots.append(root)
                }
            }
        }

        outlineView.reloadData()

        if isSearching {
            // マッチしたすべてのディレクトリを展開
            expandFilteredTree(filteredRoots)
        }
    }

    /// 指定ノード以下を走査し、マッチするノードを filteredChildren に蓄積する。
    /// 除外ルールで弾かれたノードは検索対象外 (表示と検索を完全一致させる)。
    /// - Returns: このノードが結果に含まれるべきか (自身がマッチ or 子孫がマッチ)
    private func walkForSearch(node: FileTreeNode, query: String) -> Bool {
        let isMatch = node.name.lowercased().contains(query)
        if node.isDirectory {
            if node.children == nil {
                node.children = loadAndFilter(directory: node.url, parent: node)
            }
            var matchedChildren: [FileTreeNode] = []
            for child in node.children ?? [] {
                if walkForSearch(node: child, query: query) {
                    matchedChildren.append(child)
                }
            }
            if isMatch || !matchedChildren.isEmpty {
                filteredChildren[ObjectIdentifier(node)] = matchedChildren
                return true
            }
            return false
        }
        return isMatch
    }

    /// フィルタされたツリーのディレクトリをすべて展開する
    private func expandFilteredTree(_ nodes: [FileTreeNode]) {
        for node in nodes where node.isDirectory {
            outlineView.expandItem(node)
            expandFilteredTree(filteredChildren[ObjectIdentifier(node)] ?? [])
        }
    }

    // NSSearchFieldDelegate / NSControlTextEditingDelegate: Esc や Enter の処理
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Esc で検索バーを閉じる
            closeSearchBar()
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter で選択中を Preview で開く (フォーカスは outlineView 側)
            previewSelectedAction()
            return true
        }
        return false
    }

    /// NSOutlineView のダブルクリックハンドラ: ファイルなら新しい Preview を開く
    @objc private func handleDoubleClick() {
        let row = outlineView.clickedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? FileTreeNode else { return }
        if node.isDirectory {
            // ディレクトリは展開/折りたたみをトグル
            if outlineView.isItemExpanded(node) {
                outlineView.collapseItem(node)
            } else {
                outlineView.expandItem(node)
            }
            return
        }
        // PaneView の simultaneousGesture が先に active を設定済み
        owner?.registry?.openPreview(for: node.url)
    }

    /// 実効ルートディレクトリ (customRoot が設定されていれば優先、なければ projectRoot)
    private var effectiveRoot: URL? {
        owner?.customRoot ?? workspace?.projectRoot
    }

    /// ルートディレクトリを再読み込みする。customRoot が設定されていればそちらを優先する。
    func reload() {
        guard let root = effectiveRoot else {
            currentRoot = nil
            rootNodes = []
            outlineView.reloadData()
            watcher.stop()
            updateNavigateBar()
            return
        }
        currentRoot = root
        // 要約ストアは projectRoot 基準 (.aidea の場所)。customRoot 切替時もファイルは同じ
        if let projectRoot = workspace?.projectRoot {
            summaryStore = DirectorySummaryStore(projectRoot: projectRoot)
        }
        rootNodes = loadAndFilter(directory: root)
        outlineView.reloadData()
        // owner に保存された展開 URL があればそれを復元する
        // (展開通知 outlineViewItemDidExpand が発火し、展開先の要約バッチも走る)
        if let saved = owner?.expandedURLs, !saved.isEmpty {
            restoreExpandedState(in: rootNodes, expandedURLs: saved)
        }
        // ルート直下サブディレクトリの未保存要約を一括生成 (issue #193)
        scheduleSummaryBatch(for: rootNodes)
        watcher.start(path: root.path) { [weak self] paths in
            guard let self = self else { return }
            let matcher = self.excludeMatcher()
            let rootPath = root.standardizedFileURL.path
            let relevant = paths.filter { path in
                // 除外ルールにマッチした path 配下の変更は無視する
                guard path.hasPrefix(rootPath) else { return true }
                let relative = String(path.dropFirst(rootPath.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return !matcher.matches(relativePath: relative)
            }
            if relevant.isEmpty { return }
            self.reloadWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.handleFileSystemChange()
            }
            self.reloadWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        }
        updateNavigateBar()
    }

    /// FSEvents 通知を受けたときの処理。展開状態と選択状態を可能な限り保持する。
    private func handleFileSystemChange() {
        guard let root = currentRoot else { return }
        let expandedURLs = collectExpandedURLs()
        let selectedURLs = selectedNodeURLs()
        rootNodes = loadAndFilter(directory: root)
        outlineView.reloadData()
        restoreExpandedState(in: rootNodes, expandedURLs: expandedURLs)
        restoreSelection(to: selectedURLs)
    }

    /// 現在選択されているノードの URL 一覧
    private func selectedNodeURLs() -> [URL] {
        outlineView.selectedRowIndexes.compactMap { row in
            (outlineView.item(atRow: row) as? FileTreeNode)?.url
        }
    }

    /// 指定 URL 集合にマッチするノードを現在のツリーから探して選択状態に戻す
    private func restoreSelection(to urls: [URL]) {
        guard !urls.isEmpty else { return }
        let urlSet = Set(urls)
        var rows: IndexSet = []
        func walk(_ nodes: [FileTreeNode]) {
            for node in nodes {
                if urlSet.contains(node.url) {
                    let row = outlineView.row(forItem: node)
                    if row >= 0 { rows.insert(row) }
                }
                if let children = node.children { walk(children) }
            }
        }
        walk(rootNodes)
        if !rows.isEmpty {
            outlineView.selectRowIndexes(rows, byExtendingSelection: false)
        }
    }

    /// 現在 outlineView で展開されているノードの URL を集める (永続化・リロード用)
    func collectExpandedURLs() -> Set<URL> {
        var urls: Set<URL> = []
        func walk(_ nodes: [FileTreeNode]) {
            for node in nodes where outlineView.isItemExpanded(node) {
                urls.insert(node.url)
                if let children = node.children { walk(children) }
            }
        }
        walk(rootNodes)
        return urls
    }

    /// 走査結果のツリーから、以前展開されていた URL に対応するノードを再展開する
    private func restoreExpandedState(in nodes: [FileTreeNode], expandedURLs: Set<URL>) {
        for node in nodes where expandedURLs.contains(node.url) {
            if node.children == nil {
                node.children = loadAndFilter(directory: node.url, parent: node)
            }
            outlineView.expandItem(node)
            if let children = node.children {
                restoreExpandedState(in: children, expandedURLs: expandedURLs)
            }
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if isSearching {
            if item == nil { return filteredRoots.count }
            if let node = item as? FileTreeNode {
                return filteredChildren[ObjectIdentifier(node)]?.count ?? 0
            }
            return 0
        }
        let node = item as? FileTreeNode
        if node == nil { return rootNodes.count }
        guard node!.isDirectory else { return 0 }
        if node!.children == nil {
            node!.children = loadAndFilter(directory: node!.url, parent: node!)
        }
        return node!.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if isSearching {
            if item == nil { return filteredRoots[index] }
            if let node = item as? FileTreeNode {
                return filteredChildren[ObjectIdentifier(node)]![index]
            }
        }
        if let node = item as? FileTreeNode {
            return node.children![index]
        }
        return rootNodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileTreeNode)?.isDirectory ?? false
    }

    // MARK: - Drag & Drop

    /// ドラッグ対象をペーストボードに書き込む。root 自身はドラッグ禁止。
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let node = item as? FileTreeNode else { return nil }
        if node.url == currentRoot { return nil }
        return node.url as NSURL
    }

    /// ドロップターゲットの検証。ディレクトリ or 空白のみ accept。
    func outlineView(
        _ outlineView: NSOutlineView,
        validateDrop info: NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        let targetDir = targetDirectoryForDrop(item: item, outlineView: outlineView)
        guard let targetDir = targetDir else { return [] }

        // ペーストボードからソース URL を取得して妥当性を検証
        let sourceURLs = draggedURLs(from: info)
        for source in sourceURLs {
            // 移動元ディレクトリが同じ (同一親) なら no-op
            if source.deletingLastPathComponent().standardizedFileURL == targetDir.standardizedFileURL {
                return []
            }
            // ディレクトリを自身 or その配下にドロップ禁止
            if source.standardizedFileURL == targetDir.standardizedFileURL { return [] }
            if targetDir.path.hasPrefix(source.path + "/") { return [] }
        }
        return .move
    }

    /// ドロップを受け入れて FileManager.moveItem で実際に移動する。
    func outlineView(
        _ outlineView: NSOutlineView,
        acceptDrop info: NSDraggingInfo,
        item: Any?,
        childIndex index: Int
    ) -> Bool {
        guard let targetDir = targetDirectoryForDrop(item: item, outlineView: outlineView) else { return false }
        let sourceURLs = draggedURLs(from: info)
        if sourceURLs.isEmpty { return false }

        var lastMoved: URL?
        let actionName = sourceURLs.count == 1 ? "移動" : "\(sourceURLs.count) 個を移動"
        owner?.undoManager.beginUndoGrouping()
        for source in sourceURLs {
            let dest = targetDir.appendingPathComponent(source.lastPathComponent)

            // 同名が既にある場合は上書き確認ダイアログ
            if FileManager.default.fileExists(atPath: dest.path) {
                let alert = NSAlert()
                alert.messageText = "\(source.lastPathComponent) は既に存在します"
                alert.informativeText = "上書きしますか？"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "上書き")
                let cancel = alert.addButton(withTitle: "キャンセル")
                cancel.keyEquivalent = "\u{1b}"
                if alert.runModal() != .alertFirstButtonReturn {
                    continue
                }
                do {
                    try FileManager.default.removeItem(at: dest)
                } catch {
                    NSAlert(error: error).runModal()
                    continue
                }
            }

            if performUndoableMove(from: source, to: dest, actionName: actionName) {
                lastMoved = dest
                // 移動元ファイルを表示していた Preview タブを閉じる
                owner?.registry?.closePreviewsForDeleted(source, isDirectory: isDirectoryAt(dest))
            }
        }
        owner?.undoManager.endUndoGrouping()
        owner?.undoManager.setActionName(actionName)

        if let moved = lastMoved {
            focusOnURL(moved)
        }
        return lastMoved != nil
    }

    /// ドロップ対象アイテムから実際の移動先ディレクトリを決定する
    private func targetDirectoryForDrop(item: Any?, outlineView: NSOutlineView) -> URL? {
        if item == nil {
            return currentRoot
        }
        guard let node = item as? FileTreeNode else { return nil }
        if node.isDirectory {
            return node.url
        }
        // ファイルにドロップしたら親ディレクトリに移動扱いにする
        return node.url.deletingLastPathComponent()
    }

    /// ドラッグ情報からファイル URL 配列を取り出す
    private func draggedURLs(from info: NSDraggingInfo) -> [URL] {
        let pb = info.draggingPasteboard
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return []
        }
        return urls
    }

    /// 指定 URL がディレクトリか (存在しない場合は false)
    private func isDirectoryAt(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FileTreeNode else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("FileCell")
        let cell: FileCellView
        if let recycled = outlineView.makeView(withIdentifier: identifier, owner: self) as? FileCellView {
            cell = recycled
        } else {
            cell = FileCellView()
            cell.identifier = identifier
        }
        // 検索中はマッチ文字をハイライトした AttributedString を使う
        if isSearching, let textField = cell.textField {
            textField.attributedStringValue = makeHighlightedName(node.name, query: searchQuery)
        } else {
            cell.textField?.stringValue = node.name
        }
        // ディレクトリ行は名前の右に AI 要約を表示 (issue #193)。
        // 収まらない分は truncate し、フル文はツールチップ (マウスオーバー) で見せる。
        if node.isDirectory, let summary = summaryStore?.summary(for: summaryKey(for: node.url)) {
            cell.summaryField.stringValue = summary
            cell.toolTip = summary
        } else {
            cell.summaryField.stringValue = ""
            cell.toolTip = nil
        }
        let decoration = resolveDecoration(for: node)
        let iconName = decoration.icon ?? (node.isDirectory ? "folder" : "doc")
        // SF Symbols で見つからなければ Assets.xcassets の named asset にフォールバック (例: `drawio`)
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            ?? NSImage(named: iconName)
        cell.imageView?.image = image
        // デコレーション色は行背景に適用するため、アイコン自体は標準色のまま (tint しない)
        cell.imageView?.contentTintColor = nil
        return cell
    }

    /// 行背景にデコレーション色を反映する。検索ハイライトはセル側で attributedString に焼くため、
    /// ここでは純粋に行 background の塗り (システム選択色は AppKit が上書きする) のみ担う。
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        guard let node = item as? FileTreeNode else { return nil }
        let decoration = resolveDecoration(for: node)
        let row = DecorationRowView()
        row.decorationBackground = DecorationColorPresets.appliedBackground(for: decoration.color)
        return row
    }

    /// 現在のデコレーション (default + user) で指定 node の装飾を解決する。
    /// projectRoot 自身と root 直下の特殊ノードに対するパスは `currentRoot` 相対で計算。
    private func resolveDecoration(for node: FileTreeNode) -> DecorationMatcher.Resolved {
        let userRules = owner?.userDecorationRules ?? []
        let matcher = DecorationMatcher(
            defaults: FilerSessionState.defaultDecorationRules,
            userRules: userRules
        )
        // ディレクトリは defaults をスキップして "folder" 既定 (背景色は user rule のみ適用)
        if node.isDirectory {
            let userOnly = DecorationMatcher(defaults: [], userRules: userRules)
            let resolved = userOnly.resolve(relativePath: relativePath(for: node.url))
            return DecorationMatcher.Resolved(icon: resolved.icon ?? "folder", color: resolved.color)
        }
        return matcher.resolve(relativePath: relativePath(for: node.url))
    }

    /// projectRoot からの相対パス (先頭スラッシュ無し) を返す。currentRoot 配下でなければ basename を返す。
    private func relativePath(for url: URL) -> String {
        guard let root = currentRoot?.standardizedFileURL.path else { return url.lastPathComponent }
        let target = url.standardizedFileURL.path
        if target == root { return "" }
        if target.hasPrefix(root + "/") {
            return String(target.dropFirst(root.count + 1))
        }
        return url.lastPathComponent
    }

    /// 検索クエリにマッチした文字をハイライトした NSAttributedString を作る
    private func makeHighlightedName(_ name: String, query: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: name)
        let fullRange = NSRange(location: 0, length: (name as NSString).length)
        attributed.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        guard !query.isEmpty else { return attributed }
        var searchStart = name.startIndex
        let lowerName = name.lowercased()
        let lowerQuery = query.lowercased()
        while searchStart < name.endIndex,
              let range = lowerName.range(of: lowerQuery, options: [], range: searchStart..<name.endIndex) {
            let nsRange = NSRange(range, in: name)
            attributed.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.6), range: nsRange)
            attributed.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize), range: nsRange)
            searchStart = range.upperBound
        }
        return attributed
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? FileTreeNode else { return }
        if !node.isDirectory {
            owner?.selectedFile = node.url
        }
    }

    // MARK: - Directory Summary batch (issue #193)

    /// 要約ストアのキー。projectRoot 相対パス (root 自身は ".")、projectRoot 外は絶対パス。
    private func summaryKey(for url: URL) -> String {
        guard let root = workspace?.projectRoot?.standardizedFileURL.path else {
            return url.standardizedFileURL.path
        }
        let target = url.standardizedFileURL.path
        if target == root { return "." }
        if target.hasPrefix(root + "/") { return String(target.dropFirst(root.count + 1)) }
        return target
    }

    /// 指定ノード群のうち「未保存のディレクトリ」の要約を一括生成して保存する。
    /// ルート読み込み時とノード展開時に呼ばれる (直下のみ・再帰しない)。
    /// API 負荷を抑えるため 1 件ずつ直列で生成し、完了ごとに該当行を再描画する。
    /// docs/specs/tools/filer.md#showdirectorysummary 参照。
    private func scheduleSummaryBatch(for nodes: [FileTreeNode]) {
        guard DirectorySummaryService.hasApiKey, let store = summaryStore else { return }
        // 子エントリ一覧はメインスレッドで先に確定させる (FileTreeNode を Task へ持ち込まない)
        var targets: [(url: URL, key: String, children: [String])] = []
        for node in nodes where node.isDirectory {
            let key = summaryKey(for: node.url)
            guard store.summary(for: key) == nil, !summaryInFlight.contains(node.url) else { continue }
            let children: [String]
            if let loaded = node.children {
                children = loaded.map(\.name)
            } else {
                children = FileTreeLoader.load(directory: node.url, parent: node).map(\.name)
            }
            summaryInFlight.insert(node.url)
            targets.append((node.url, key, children))
        }
        guard !targets.isEmpty else { return }

        Task { [weak self] in
            for target in targets {
                let summary = await DirectorySummaryService.generate(
                    directoryURL: target.url,
                    children: target.children
                )
                guard let self else { return }
                await MainActor.run {
                    self.summaryInFlight.remove(target.url)
                    guard let summary else { return }
                    self.summaryStore?.set(summary, for: target.key)
                    self.reloadRow(forURL: target.url)
                }
            }
        }
    }

    /// 表示中の行から URL 一致するものを探して再描画する (要約の逐次反映用)。
    /// FSEvents 再読込等でノードが差し替わっていても URL で追従できる。
    private func reloadRow(forURL url: URL) {
        for row in 0..<outlineView.numberOfRows {
            if let node = outlineView.item(atRow: row) as? FileTreeNode, node.url == url {
                outlineView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
                return
            }
        }
    }

    /// ユーザー操作でノードが展開されたとき、owner の expandedURLs に記録する (永続化対象)。
    /// あわせて展開先直下のサブディレクトリの要約を一括生成する (issue #193)。
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FileTreeNode else { return }
        owner?.expandedURLs.insert(node.url)
        scheduleSummaryBatch(for: node.children ?? [])
    }

    /// ユーザー操作でノードが折りたたまれたとき、owner の expandedURLs から削除する
    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FileTreeNode else { return }
        owner?.expandedURLs.remove(node.url)
    }

    // MARK: - Keyboard Actions

    /// Enter キー: 単一選択中のノードがファイルなら Preview で開く、
    /// ディレクトリなら展開/折りたたみ。複数選択時はファイルのみ Preview で開く。
    func previewSelectedAction() {
        let nodes = selectedNodes()
        if nodes.count == 1, let node = nodes.first {
            if node.isDirectory {
                if outlineView.isItemExpanded(node) {
                    outlineView.collapseItem(node)
                } else {
                    outlineView.expandItem(node)
                }
            } else {
                owner?.registry?.openPreview(for: node.url)
            }
            return
        }
        for node in nodes where !node.isDirectory {
            owner?.registry?.openPreview(for: node.url)
        }
    }

    /// 選択中の FileTreeNode 一覧
    private func selectedNodes() -> [FileTreeNode] {
        outlineView.selectedRowIndexes.compactMap { row in
            outlineView.item(atRow: row) as? FileTreeNode
        }
    }

    /// Shift+Enter キー: 選択ノードの名前変更 (単一選択時のみ)
    func renameSelectedAction() {
        let nodes = selectedNodes()
        guard nodes.count == 1, let node = nodes.first else { return }
        // projectRoot (ルート) 自身は変更不可
        if node.url == currentRoot { return }

        let parent = node.url.deletingLastPathComponent()
        guard let newName = FileNameInputDialog.show(
            title: "名前を変更",
            prompt: "新しい名前を入力してください",
            initial: node.name,
            parentDirectory: parent,
            excludingName: node.name
        ) else { return }

        let newURL = parent.appendingPathComponent(newName)
        if performUndoableMove(from: node.url, to: newURL, actionName: "リネーム") {
            focusOnURL(newURL)
        }
    }

    /// Backspace キー: 選択ノードを削除 (確認ダイアログ → ゴミ箱)。複数選択対応。
    func deleteSelectedAction() {
        let nodes = selectedNodes().filter { $0.url != currentRoot }
        if nodes.isEmpty { return }

        let alert = NSAlert()
        if nodes.count == 1, let node = nodes.first {
            alert.messageText = "\(node.name) を削除しますか？"
            alert.informativeText = node.isDirectory
                ? "このディレクトリと配下のすべてのファイルがゴミ箱に移動されます。"
                : "このファイルはゴミ箱に移動されます。"
        } else {
            alert.messageText = "\(nodes.count) 個の項目を削除しますか？"
            let names = nodes.prefix(5).map(\.name).joined(separator: ", ")
            let suffix = nodes.count > 5 ? "\(names), ... など \(nodes.count) 個" : names
            alert.informativeText = "選択中のファイル/ディレクトリがゴミ箱に移動されます。\n\(suffix)"
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "削除")
        let cancelButton = alert.addButton(withTitle: "キャンセル")
        cancelButton.keyEquivalent = "\u{1b}"

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let actionName = nodes.count == 1 ? "削除" : "\(nodes.count) 個を削除"
        owner?.undoManager.beginUndoGrouping()
        for node in nodes {
            if performUndoableTrash(at: node.url, actionName: actionName) {
                owner?.registry?.closePreviewsForDeleted(node.url, isDirectory: node.isDirectory)
            }
        }
        owner?.undoManager.endUndoGrouping()
        owner?.undoManager.setActionName(actionName)
    }

    /// Cmd+N キー: 新規ファイル作成
    func createFileAction() {
        guard let parent = targetParentDirectory() else { return }
        guard let name = FileNameInputDialog.show(
            title: "新しいファイル",
            prompt: "ファイル名を入力してください",
            initial: "",
            parentDirectory: parent
        ) else { return }

        let newURL = parent.appendingPathComponent(name)
        let created = FileManager.default.createFile(atPath: newURL.path, contents: nil)
        if created {
            // アンドゥ: 作成された URL を trash する (redo は restore で連鎖)
            let actionName = "新規ファイル作成"
            owner?.undoManager.registerUndo(withTarget: self) { target in
                _ = target.performUndoableTrash(at: newURL, actionName: actionName)
            }
            owner?.undoManager.setActionName(actionName)
            focusOnURL(newURL)
        } else {
            let alert = NSAlert()
            alert.messageText = "ファイルを作成できませんでした"
            alert.informativeText = newURL.path
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    /// Cmd+Shift+N キー: 新規ディレクトリ作成
    func createDirectoryAction() {
        guard let parent = targetParentDirectory() else { return }
        guard let name = FileNameInputDialog.show(
            title: "新しいディレクトリ",
            prompt: "ディレクトリ名を入力してください",
            initial: "",
            parentDirectory: parent
        ) else { return }

        let newURL = parent.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(
                at: newURL,
                withIntermediateDirectories: false
            )
            // アンドゥ: 作成された URL を trash する (redo は restore で連鎖)
            let actionName = "新規ディレクトリ作成"
            owner?.undoManager.registerUndo(withTarget: self) { target in
                _ = target.performUndoableTrash(at: newURL, actionName: actionName)
            }
            owner?.undoManager.setActionName(actionName)
            focusOnURL(newURL)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// 新規作成時の親ディレクトリを決定する:
    /// - 選択が単一でディレクトリなら: その中
    /// - 選択が単一でファイルなら: その親
    /// - 複数選択 or 選択なし: projectRoot
    private func targetParentDirectory() -> URL? {
        let nodes = selectedNodes()
        if nodes.count == 1, let node = nodes.first {
            return node.isDirectory ? node.url : node.url.deletingLastPathComponent()
        }
        return currentRoot
    }

    /// 「単一選択かつ非 root」のとき選択ノードを返す。それ以外は nil。
    /// openInFinder / openWith など projectRoot 自身を対象外にしたい操作で共用。
    private func singleSelectedNonRoot() -> FileTreeNode? {
        let nodes = selectedNodes()
        guard nodes.count == 1, let node = nodes.first, node.url != currentRoot else {
            return nil
        }
        return node
    }

    // MARK: - Copy / Paste

    /// Cmd+C: 選択ノード (projectRoot 除く) を `NSPasteboard.general` に
    /// `NSPasteboard.PasteboardType.fileURL` 形式で書き込む。
    /// 対象が 0 件のときは NSBeep で no-op。macOS 標準形式なので Finder 等と相互運用可能。
    func copySelectedAction() {
        let urls = selectedNodes()
            .filter { $0.url != currentRoot }
            .map { $0.url }
        guard !urls.isEmpty else {
            NSSound.beep()
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    /// Cmd+V: `NSPasteboard.general` から file URL を取り出し、
    /// `targetParentDirectory()` で決まる貼り付け先ディレクトリへ `copyItem` で物理コピーする。
    /// 同名衝突時は `nextAvailableURL` で `_N` をインクリメントしてリネーム。
    /// ペースト完了後、新しく作成されたエントリ群を選択状態にフォーカスする。
    func pasteFromClipboardAction() {
        let pasteboard = NSPasteboard.general
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let sources = (pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
        guard !sources.isEmpty else {
            NSSound.beep()
            return
        }
        guard let destination = targetParentDirectory() else {
            NSSound.beep()
            return
        }

        var createdURLs: [URL] = []
        var firstError: Error?
        for source in sources {
            let target = nextAvailableURL(in: destination, for: source.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: source, to: target)
                createdURLs.append(target)
            } catch {
                if firstError == nil { firstError = error }
            }
        }

        if !createdURLs.isEmpty {
            // アンドゥ: ペーストで作成された URL 群を 1 グループとして trash する
            let actionName = createdURLs.count == 1 ? "ペースト" : "\(createdURLs.count) 個をペースト"
            owner?.undoManager.beginUndoGrouping()
            for createdURL in createdURLs {
                owner?.undoManager.registerUndo(withTarget: self) { target in
                    _ = target.performUndoableTrash(at: createdURL, actionName: actionName)
                }
            }
            owner?.undoManager.endUndoGrouping()
            owner?.undoManager.setActionName(actionName)
            focusOnURLs(createdURLs)
        }
        if let error = firstError {
            NSAlert(error: error).runModal()
        }
    }

    /// 指定ディレクトリ内で、元のエントリ名と同名がある場合に衝突しない名前 URL を返す。
    /// 衝突なしならそのまま、衝突ありなら `_2`, `_3`, ... をインクリメントして探す。
    /// 拡張子あり (`foo.txt`) → 拡張子の前に `_N` を差し込む (`foo_2.txt`)。
    /// 拡張子なし (`README`) / ディレクトリ (`mydir`) → 末尾に `_N` を付ける (`README_2` / `mydir_2`)。
    private func nextAvailableURL(in directory: URL, for originalName: String) -> URL {
        let candidate = directory.appendingPathComponent(originalName)
        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        let ext = (originalName as NSString).pathExtension
        let base = (originalName as NSString).deletingPathExtension
        var index = 2
        while true {
            let newName: String
            if ext.isEmpty {
                newName = "\(base)_\(index)"
            } else {
                newName = "\(base)_\(index).\(ext)"
            }
            let newURL = directory.appendingPathComponent(newName)
            if !FileManager.default.fileExists(atPath: newURL.path) {
                return newURL
            }
            index += 1
        }
    }

    /// 複数 URL を選択状態にフォーカスする。ペースト/移動など複数ノード作成後に使う。
    /// 内部で一度だけ `handleFileSystemChange()` を呼んでから IndexSet を構築する。
    /// 先頭 URL の親まで展開し、末尾 URL を scrollRowToVisible で表示に寄せる。
    private func focusOnURLs(_ urls: [URL]) {
        guard !urls.isEmpty, let root = currentRoot else { return }
        handleFileSystemChange()

        // 対象ノードへ辿り着くためにそれぞれの親ディレクトリを展開しておく
        for url in urls {
            let rootPath = root.path
            guard url.path.hasPrefix(rootPath) else { continue }
            let relative = String(url.path.dropFirst(rootPath.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if relative.isEmpty { continue }
            let components = relative.split(separator: "/").map(String.init)
            var currentList: [FileTreeNode] = rootNodes
            for (i, name) in components.enumerated() {
                guard let node = currentList.first(where: { $0.name == name }) else { break }
                if i < components.count - 1 {
                    if node.children == nil {
                        node.children = loadAndFilter(directory: node.url, parent: node)
                    }
                    outlineView.expandItem(node)
                    currentList = node.children ?? []
                }
            }
        }

        var indexes = IndexSet()
        var lastRow = -1
        for url in urls {
            guard let node = findNode(matching: url, in: rootNodes) else { continue }
            let row = outlineView.row(forItem: node)
            if row >= 0 {
                indexes.insert(row)
                lastRow = row
            }
        }
        if !indexes.isEmpty {
            outlineView.selectRowIndexes(indexes, byExtendingSelection: false)
            if lastRow >= 0 {
                outlineView.scrollRowToVisible(lastRow)
            }
            outlineView.window?.makeFirstResponder(outlineView)
        }
    }

    /// 指定 URL に一致するノードを `rootNodes` から再帰的に探す。
    /// ディレクトリの子はロード済みに限り走査 (未ロード分は `focusOnURLs` 側で事前に expand 済み)。
    private func findNode(matching url: URL, in nodes: [FileTreeNode]) -> FileTreeNode? {
        for node in nodes {
            if node.url == url { return node }
            if let children = node.children,
               let hit = findNode(matching: url, in: children) {
                return hit
            }
        }
        return nil
    }

    // MARK: - Open in Finder / Open With

    /// Ctrl+O: 選択ノードを Finder で開く (単一選択かつ非 root のときのみ)。
    /// ファイル: 親フォルダを開いて該当ファイルを選択状態にする。
    /// ディレクトリ: そのフォルダ自体を Finder で開く。
    /// 条件不一致のときは NSBeep して no-op。
    func openInFinderAction() {
        guard let node = singleSelectedNonRoot() else {
            NSSound.beep()
            return
        }
        if node.isDirectory {
            NSWorkspace.shared.open(node.url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
        }
    }

    /// Ctrl+A: 「指定のアプリケーションで開く」メニューを NSMenu でポップアップ表示する
    /// (単一選択かつ非 root のときのみ)。候補 0 件でも末尾の「その他...」だけで表示する。
    /// 候補は OS 標準の `urlsForApplications(toOpen:)` から取得し、右クリックの
    /// サブメニューと同一の構築関数 `buildOpenWithMenu` を共用する。
    func openWithAction() {
        guard let node = singleSelectedNonRoot() else {
            NSSound.beep()
            return
        }
        let menu = buildOpenWithMenu(for: node)
        let row = outlineView.row(forItem: node)
        let pointInScreen = popUpAnchorScreenPoint(forRow: row)
        menu.popUp(positioning: nil, at: pointInScreen, in: nil)
    }

    /// 「指定のアプリで開く」サブメニュー / Ctrl+A ポップアップで共用する NSMenu を構築する。
    /// macOS Finder の「このアプリケーションで開く」に準拠した構成:
    ///   1. デフォルトアプリ (取得できた場合のみ) — 「{名前} (デフォルト)」
    ///   2. 区切り線 (デフォルトアプリがある場合のみ)
    ///   3. 候補アプリ一覧 — デフォルトと重複するものは除く
    ///   4. 区切り線 (常に)
    ///   5. その他... — NSOpenPanel でアプリを選ばせて開く
    private func buildOpenWithMenu(for node: FileTreeNode) -> NSMenu {
        let menu = NSMenu()
        let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: node.url)
        let candidates = NSWorkspace.shared.urlsForApplications(toOpen: node.url)

        if let defaultURL = defaultAppURL {
            menu.addItem(makeOpenWithMenuItem(for: node, appURL: defaultURL, isDefault: true))
            menu.addItem(NSMenuItem.separator())
        }

        for appURL in candidates where appURL != defaultAppURL {
            menu.addItem(makeOpenWithMenuItem(for: node, appURL: appURL, isDefault: false))
        }

        menu.addItem(NSMenuItem.separator())
        let otherItem = ClosureMenuItem(title: "その他...", image: nil) { [weak self] in
            self?.openWithOther(node: node)
        }
        menu.addItem(otherItem)
        return menu
    }

    /// 「指定のアプリで開く」メニュー内の 1 項目を生成する。
    /// `isDefault` が true のときは表示名の末尾に「 (デフォルト)」を付ける。
    private func makeOpenWithMenuItem(for node: FileTreeNode, appURL: URL, isDefault: Bool) -> NSMenuItem {
        // ローカライズされたアプリ名 (例: "Visual Studio Code.app" → "Visual Studio Code"、
        // 各言語にローカライズされている場合はそれ)。取得失敗時は拡張子なしのファイル名でフォールバック
        let resourceValues = try? appURL.resourceValues(forKeys: [.localizedNameKey])
        let baseName = resourceValues?.localizedName
            ?? appURL.deletingPathExtension().lastPathComponent
        let title = isDefault ? "\(baseName) (デフォルト)" : baseName
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 16, height: 16)
        return ClosureMenuItem(title: title, image: icon) { [weak self] in
            self?.openNode(node, with: appURL)
        }
    }

    /// 「その他...」を選んだときの処理。NSOpenPanel でアプリを選ばせて `openNode` を呼ぶ。
    /// `/Applications` を起点にして `UTType.application` のみ選択可能とする。
    private func openWithOther(node: FileTreeNode) {
        let panel = NSOpenPanel()
        panel.title = "アプリケーションを選択"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [UTType.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let appURL = panel.url {
            openNode(node, with: appURL)
        }
    }

    /// 選択ノードを指定のアプリケーションで開く。エラーは NSAlert で通知。
    private func openNode(_ node: FileTreeNode, with appURL: URL) {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [node.url],
            withApplicationAt: appURL,
            configuration: config
        ) { _, error in
            guard let error = error else { return }
            DispatchQueue.main.async {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// Ctrl+A ポップアップの表示位置 (screen 座標)。指定行の左下に揃える。
    /// 行が見つからないときは現在のマウス位置を返す。
    private func popUpAnchorScreenPoint(forRow row: Int) -> NSPoint {
        guard row >= 0 else { return NSEvent.mouseLocation }
        let rowRect = outlineView.rect(ofRow: row)
        let pointInView = NSPoint(x: rowRect.minX, y: rowRect.maxY)
        let pointInWindow = outlineView.convert(pointInView, to: nil)
        guard let window = outlineView.window else { return NSEvent.mouseLocation }
        let screenRect = window.convertToScreen(NSRect(origin: pointInWindow, size: .zero))
        return screenRect.origin
    }

    // MARK: - Context Menu

    /// 右クリックメニューを生成する。選択状態に応じて項目の有効/無効を切替。
    func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let nodes = selectedNodes()
        let hasSelection = !nodes.isEmpty
        let isSingle = nodes.count == 1
        let singleIsRoot = isSingle && nodes.first?.url == currentRoot
        let hasOnlyFiles = hasSelection && nodes.allSatisfy { !$0.isDirectory }

        let previewItem = NSMenuItem(
            title: "プレビューで開く",
            action: #selector(contextPreview),
            keyEquivalent: "\r"
        )
        previewItem.target = self
        previewItem.isEnabled = hasOnlyFiles
        menu.addItem(previewItem)

        let renameItem = NSMenuItem(
            title: "名前を変更",
            action: #selector(contextRename),
            keyEquivalent: "\r"
        )
        renameItem.keyEquivalentModifierMask = [.shift]
        renameItem.target = self
        renameItem.isEnabled = isSingle && !singleIsRoot
        menu.addItem(renameItem)

        menu.addItem(NSMenuItem.separator())

        let newFileItem = NSMenuItem(
            title: "新規ファイル",
            action: #selector(contextNewFile),
            keyEquivalent: "n"
        )
        newFileItem.keyEquivalentModifierMask = [.command]
        newFileItem.target = self
        newFileItem.isEnabled = true
        menu.addItem(newFileItem)

        let newDirItem = NSMenuItem(
            title: "新規ディレクトリ",
            action: #selector(contextNewDir),
            keyEquivalent: "n"
        )
        newDirItem.keyEquivalentModifierMask = [.command, .shift]
        newDirItem.target = self
        newDirItem.isEnabled = true
        menu.addItem(newDirItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(
            title: "削除",
            action: #selector(contextDelete),
            keyEquivalent: String(Character(UnicodeScalar(NSDeleteCharacter)!))
        )
        deleteItem.target = self
        deleteItem.isEnabled = hasSelection && nodes.contains { $0.url != currentRoot }
        menu.addItem(deleteItem)

        menu.addItem(NSMenuItem.separator())

        // 「Finder で開く」(⌃O): 単一選択かつ非 root のとき有効
        let openInFinderItem = NSMenuItem(
            title: "Finder で開く",
            action: #selector(contextOpenInFinder),
            keyEquivalent: "o"
        )
        openInFinderItem.keyEquivalentModifierMask = [.control]
        openInFinderItem.target = self
        openInFinderItem.isEnabled = isSingle && !singleIsRoot
        menu.addItem(openInFinderItem)

        // 「指定のアプリケーションで開く」(⌃A): 単一選択かつ非 root のとき有効
        // サブメニューには Ctrl+A ポップアップと同じ buildOpenWithMenu の結果を入れる
        // (候補 0 件でも末尾の「その他...」が常にあるため有効)
        let openWithItem = NSMenuItem(
            title: "指定のアプリケーションで開く",
            action: nil,
            keyEquivalent: "a"
        )
        openWithItem.keyEquivalentModifierMask = [.control]
        openWithItem.target = self
        if isSingle, !singleIsRoot, let node = nodes.first {
            openWithItem.submenu = buildOpenWithMenu(for: node)
            openWithItem.isEnabled = true
        } else {
            openWithItem.isEnabled = false
        }
        menu.addItem(openWithItem)

        menu.addItem(NSMenuItem.separator())

        // 「コピー」(⌘C): 選択ありかつ非 root が含まれるとき有効
        let copyItem = NSMenuItem(
            title: "コピー",
            action: #selector(contextCopy),
            keyEquivalent: "c"
        )
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = self
        copyItem.isEnabled = hasSelection && nodes.contains { $0.url != currentRoot }
        menu.addItem(copyItem)

        // 「ペースト」(⌘V): クリップボードに fileURL があり、貼り付け先が決定できるとき有効
        let pasteItem = NSMenuItem(
            title: "ペースト",
            action: #selector(contextPaste),
            keyEquivalent: "v"
        )
        pasteItem.keyEquivalentModifierMask = [.command]
        pasteItem.target = self
        let pasteboard = NSPasteboard.general
        let pasteboardHasFileURL = pasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        pasteItem.isEnabled = pasteboardHasFileURL && targetParentDirectory() != nil
        menu.addItem(pasteItem)

        menu.addItem(NSMenuItem.separator())

        let excludeItem = NSMenuItem(
            title: "除外ルール設定...",
            action: #selector(contextEditExcludeRules),
            keyEquivalent: ""
        )
        excludeItem.target = self
        excludeItem.isEnabled = true
        menu.addItem(excludeItem)

        let decorationItem = NSMenuItem(
            title: "デコレーションルール...",
            action: #selector(contextEditDecorationRules),
            keyEquivalent: ""
        )
        decorationItem.target = self
        decorationItem.isEnabled = true
        menu.addItem(decorationItem)

        return menu
    }

    @objc private func contextPreview() { previewSelectedAction() }
    @objc private func contextRename() { renameSelectedAction() }
    @objc private func contextNewFile() { createFileAction() }
    @objc private func contextNewDir() { createDirectoryAction() }
    @objc private func contextDelete() { deleteSelectedAction() }
    @objc private func contextOpenInFinder() { openInFinderAction() }
    @objc private func contextCopy() { copySelectedAction() }
    @objc private func contextPaste() { pasteFromClipboardAction() }
    @objc private func contextEditExcludeRules() { editExcludeRulesAction() }
    @objc private func contextEditDecorationRules() { editDecorationRulesAction() }

    /// 除外ルール編集ダイアログを表示し、OK で owner.excludeRules を更新して再描画する
    func editExcludeRulesAction() {
        let current = owner?.excludeRules ?? FilerSessionState.defaultExcludeRules
        guard let updated = ExcludeRulesDialog.show(
            initial: current,
            defaults: FilerSessionState.defaultExcludeRules
        ) else { return }
        owner?.excludeRules = updated
        // 表示と検索を即座に再評価
        handleFileSystemChange()
        if isSearching {
            applySearch(searchQuery)
        }
    }

    /// デコレーションルール編集ダイアログを表示し、OK で owner.userDecorationRules を更新して再描画する
    func editDecorationRulesAction() {
        let current = owner?.userDecorationRules ?? []
        guard let updated = DecorationRulesDialog.show(initial: current) else { return }
        owner?.userDecorationRules = updated
        outlineView.reloadData()
    }

    /// 指定 URL のノードにフォーカスする (明示的に再取得してから選択する)。
    /// 親ディレクトリを順に展開してターゲットを可視化する。
    /// - Parameter centered: true のときスクロール位置を中央に寄せる (Preview タブ「ファイラで選択」用、issue #238)。
    ///   false (既定) のときは `scrollRowToVisible` で「見える位置まで」のみ寄せる (rename/move/create 後のフォーカス)。
    func focusOnURL(_ url: URL, centered: Bool = false) {
        guard let root = currentRoot else { return }
        // 再取得 (展開状態は collectExpandedURLs / restoreExpandedState で復元される)
        handleFileSystemChange()

        // root からの相対パスを取り出す
        let rootPath = root.path
        guard url.path.hasPrefix(rootPath) else { return }
        let relative = String(url.path.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if relative.isEmpty { return }
        let components = relative.split(separator: "/").map(String.init)

        // ツリーを辿りながら親ディレクトリを展開していく
        var currentList: [FileTreeNode] = rootNodes
        var targetNode: FileTreeNode?
        for (i, name) in components.enumerated() {
            guard let node = currentList.first(where: { $0.name == name }) else { return }
            targetNode = node
            // 末端以外のディレクトリは展開する
            if i < components.count - 1 {
                if node.children == nil {
                    node.children = loadAndFilter(directory: node.url, parent: node)
                }
                outlineView.expandItem(node)
                currentList = node.children ?? []
            }
        }

        guard let target = targetNode else { return }
        let row = outlineView.row(forItem: target)
        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            if centered {
                scrollRowToCenter(row)
            } else {
                outlineView.scrollRowToVisible(row)
            }
            outlineView.window?.makeFirstResponder(outlineView)
            // selection change で owner?.selectedFile が更新される
        }
    }

    /// 指定行がビューポートの中央に来るようスクロールする。端では `scrollToVisible` が自動でクランプする。
    private func scrollRowToCenter(_ row: Int) {
        let rowRect = outlineView.rect(ofRow: row)
        let visibleHeight = outlineView.visibleRect.height
        guard visibleHeight > 0 else {
            outlineView.scrollRowToVisible(row)
            return
        }
        let centeredRect = NSRect(
            x: rowRect.minX,
            y: rowRect.midY - visibleHeight / 2,
            width: rowRect.width,
            height: visibleHeight
        )
        outlineView.scrollToVisible(centeredRect)
    }
}
