//
//  FilerSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// Filer Session の SwiftUI ラッパ。FilerSessionState が保持する NSViewController を再利用する。
struct FilerSessionView: NSViewControllerRepresentable {
    let session: Session
    let state: FilerSessionState
    @Environment(WorkspaceState.self) private var workspace

    func makeNSViewController(context: Context) -> FileTreeViewController {
        state.controller.workspace = workspace
        state.controller.loadViewIfNeeded()
        state.controller.reload()
        // 初期 focusableView を session にセット
        session.focusableView = state.controller.outlineView
        return state.controller
    }

    func updateNSViewController(_ vc: FileTreeViewController, context: Context) {
        if vc.currentRoot != workspace.projectRoot {
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
    private let watcher = FileWatcher()
    private var rootNodes: [FileTreeNode] = []
    private var reloadWorkItem: DispatchWorkItem?

    /// owner (FilerSessionState) の除外ルールから ExcludeMatcher を組み立てる。
    /// owner が未設定なら defaultExcludeRules を使う。
    private func excludeMatcher() -> ExcludeMatcher {
        ExcludeMatcher(patterns: owner?.excludeRules ?? FilerSessionState.defaultExcludeRules)
    }

    /// 指定ディレクトリの直下をロードし、除外ルールに該当するエントリをフィルタする。
    private func loadAndFilter(directory url: URL, parent: FileTreeNode? = nil) -> [FileTreeNode] {
        let nodes = FileTreeLoader.load(directory: url, parent: parent)
        guard let root = currentRoot else { return nodes }
        let matcher = excludeMatcher()
        return nodes.filter { node in
            let relative = Self.relativePath(of: node.url, from: root)
            return !matcher.matches(relativePath: relative)
        }
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
        outlineView.registerForDraggedTypes([.fileURL])
        outlineView.setDraggingSourceOperationMask([.move], forLocal: true)
        outlineView.setDraggingSourceOperationMask([.move], forLocal: false)
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

        let stack = NSStackView(views: [searchField, scrollView])
        stack.orientation = .vertical
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 0, right: 6)
        stack.distribution = .fill
        // searchField は hugging を強めに (縦方向に伸びないように)
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

    /// ルートディレクトリを WorkspaceState から取得して再読み込みする
    func reload() {
        guard let root = workspace?.projectRoot else {
            currentRoot = nil
            rootNodes = []
            outlineView.reloadData()
            watcher.stop()
            return
        }
        currentRoot = root
        rootNodes = loadAndFilter(directory: root)
        outlineView.reloadData()
        // owner に保存された展開 URL があればそれを復元する
        if let saved = owner?.expandedURLs, !saved.isEmpty {
            restoreExpandedState(in: rootNodes, expandedURLs: saved)
        }
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

            do {
                try FileManager.default.moveItem(at: source, to: dest)
                lastMoved = dest
                // 移動元ファイルを表示していた Preview タブを閉じる
                owner?.registry?.closePreviewsForDeleted(source, isDirectory: isDirectoryAt(dest))
            } catch {
                NSAlert(error: error).runModal()
            }
        }

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
        let cell: NSTableCellView
        if let recycled = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = recycled
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let icon = NSImageView()
            icon.translatesAutoresizingMaskIntoConstraints = false
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingMiddle
            cell.addSubview(icon)
            cell.addSubview(label)
            cell.imageView = icon
            cell.textField = label
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 16),
                icon.heightAnchor.constraint(equalToConstant: 16),
                label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        // 検索中はマッチ文字をハイライトした AttributedString を使う
        if isSearching, let textField = cell.textField {
            textField.attributedStringValue = makeHighlightedName(node.name, query: searchQuery)
        } else {
            cell.textField?.stringValue = node.name
        }
        let iconName = FileTreeLoader.iconName(for: node)
        // SF Symbols で見つからなければ Assets.xcassets の named asset にフォールバック
        // (例: `drawio` は独自アセット)
        cell.imageView?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            ?? NSImage(named: iconName)
        return cell
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
              let node = outlineView.item(atRow: row) as? FileTreeNode,
              !node.isDirectory else {
            return
        }
        owner?.selectedFile = node.url
    }

    /// ユーザー操作でノードが展開されたとき、owner の expandedURLs に記録する (永続化対象)
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? FileTreeNode else { return }
        owner?.expandedURLs.insert(node.url)
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
        do {
            try FileManager.default.moveItem(at: node.url, to: newURL)
            focusOnURL(newURL)
        } catch {
            NSAlert(error: error).runModal()
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

        for node in nodes {
            do {
                try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
                owner?.registry?.closePreviewsForDeleted(node.url, isDirectory: node.isDirectory)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
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

        let excludeItem = NSMenuItem(
            title: "除外ルール設定...",
            action: #selector(contextEditExcludeRules),
            keyEquivalent: ""
        )
        excludeItem.target = self
        excludeItem.isEnabled = true
        menu.addItem(excludeItem)

        return menu
    }

    @objc private func contextPreview() { previewSelectedAction() }
    @objc private func contextRename() { renameSelectedAction() }
    @objc private func contextNewFile() { createFileAction() }
    @objc private func contextNewDir() { createDirectoryAction() }
    @objc private func contextDelete() { deleteSelectedAction() }
    @objc private func contextEditExcludeRules() { editExcludeRulesAction() }

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

    /// 指定 URL のノードにフォーカスする (明示的に再取得してから選択する)。
    /// 親ディレクトリを順に展開してターゲットを可視化する。
    func focusOnURL(_ url: URL) {
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
            outlineView.scrollRowToVisible(row)
            outlineView.window?.makeFirstResponder(outlineView)
            // selection change で owner?.selectedFile が更新される
        }
    }
}
