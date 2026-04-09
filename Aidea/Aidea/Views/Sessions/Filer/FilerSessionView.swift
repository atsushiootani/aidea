//
//  FilerSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// Filer Session の SwiftUI ラッパ。FilerSessionState が保持する NSViewController を再利用する。
struct FilerSessionView: NSViewControllerRepresentable {
    let state: FilerSessionState
    @Environment(WorkspaceState.self) private var workspace

    func makeNSViewController(context: Context) -> FileTreeViewController {
        state.controller.workspace = workspace
        state.controller.reload()
        return state.controller
    }

    func updateNSViewController(_ vc: FileTreeViewController, context: Context) {
        if vc.currentRoot != workspace.projectRoot {
            vc.reload()
        }
    }
}

/// NSOutlineView を保持する NSViewController。データソース・デリゲート・ファイル監視を兼ねる。
final class FileTreeViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var workspace: WorkspaceState?
    /// この Controller を所有する FilerSessionState (選択ファイルの書き戻し先)
    weak var owner: FilerSessionState?
    /// 現在表示中のルート (差分検知用)
    var currentRoot: URL?

    private let outlineView = FilerOutlineView()
    private let scrollView = NSScrollView()
    private let watcher = FileWatcher()
    private var rootNodes: [FileTreeNode] = []
    private var reloadWorkItem: DispatchWorkItem?
    private static let excludedDirs: Set<String> = [".git", "node_modules", ".DS_Store", "DerivedData", ".build"]

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
        outlineView.style = .sourceList
        outlineView.allowsMultipleSelection = false
        outlineView.indentationPerLevel = 14
        // キーボードイベントをこのコントローラに委譲
        outlineView.controller = self
        // ダブルクリックで Preview Session を新規作成
        outlineView.target = self
        outlineView.doubleAction = #selector(handleDoubleClick)

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        self.view = scrollView
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
        rootNodes = FileTreeLoader.load(directory: root).filter { !Self.excludedDirs.contains($0.name) }
        outlineView.reloadData()
        watcher.start(path: root.path) { [weak self] paths in
            guard let self = self else { return }
            let relevant = paths.filter { path in
                !Self.excludedDirs.contains(where: { path.contains("/\($0)/") || path.hasSuffix("/\($0)") })
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
        let selectedURL = selectedNodeURL()
        rootNodes = FileTreeLoader.load(directory: root).filter { !Self.excludedDirs.contains($0.name) }
        outlineView.reloadData()
        restoreExpandedState(in: rootNodes, expandedURLs: expandedURLs)
        if let url = selectedURL {
            restoreSelection(to: url)
        }
    }

    /// 現在選択されているノードの URL (なければ nil)
    private func selectedNodeURL() -> URL? {
        let row = outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? FileTreeNode else { return nil }
        return node.url
    }

    /// 指定 URL にマッチするノードを現在のツリーから探して選択状態に戻す
    private func restoreSelection(to url: URL) {
        func walk(_ nodes: [FileTreeNode]) -> FileTreeNode? {
            for node in nodes {
                if node.url == url { return node }
                if let children = node.children, let found = walk(children) { return found }
            }
            return nil
        }
        guard let node = walk(rootNodes) else { return }
        let row = outlineView.row(forItem: node)
        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }

    /// 現在 outlineView で展開されているノードの URL を集める
    private func collectExpandedURLs() -> Set<URL> {
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
                node.children = FileTreeLoader.load(directory: node.url, parent: node)
            }
            outlineView.expandItem(node)
            if let children = node.children {
                restoreExpandedState(in: children, expandedURLs: expandedURLs)
            }
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let node = item as? FileTreeNode
        if node == nil { return rootNodes.count }
        guard node!.isDirectory else { return 0 }
        if node!.children == nil {
            node!.children = FileTreeLoader.load(directory: node!.url, parent: node!)
        }
        return node!.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? FileTreeNode {
            return node.children![index]
        }
        return rootNodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileTreeNode)?.isDirectory ?? false
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
        cell.textField?.stringValue = node.name
        cell.imageView?.image = NSImage(
            systemSymbolName: FileTreeLoader.iconName(for: node),
            accessibilityDescription: nil
        )
        return cell
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

    // MARK: - Keyboard Actions

    /// Enter キー: 選択ノードがファイルなら Preview で開く、ディレクトリなら展開/折りたたみ
    func previewSelectedAction() {
        let row = outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? FileTreeNode else { return }
        if node.isDirectory {
            if outlineView.isItemExpanded(node) {
                outlineView.collapseItem(node)
            } else {
                outlineView.expandItem(node)
            }
        } else {
            owner?.registry?.openPreview(for: node.url)
        }
    }

    /// Shift+Enter キー: 選択ノードの名前変更
    func renameSelectedAction() {
        let row = outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? FileTreeNode else { return }
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

    /// Backspace キー: 選択ノードを削除 (確認ダイアログ → ゴミ箱)
    func deleteSelectedAction() {
        let row = outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? FileTreeNode else { return }
        if node.url == currentRoot { return }

        let alert = NSAlert()
        alert.messageText = "\(node.name) を削除しますか？"
        alert.informativeText = node.isDirectory
            ? "このディレクトリと配下のすべてのファイルがゴミ箱に移動されます。"
            : "このファイルはゴミ箱に移動されます。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "削除")
        let cancelButton = alert.addButton(withTitle: "キャンセル")
        cancelButton.keyEquivalent = "\u{1b}" // Esc でキャンセル

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
                // 削除したファイル/ディレクトリを表示している Preview タブを閉じる
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
    /// - 選択がディレクトリなら: その中
    /// - 選択がファイルなら: その親
    /// - 選択なし: projectRoot
    private func targetParentDirectory() -> URL? {
        let row = outlineView.selectedRow
        if row >= 0, let node = outlineView.item(atRow: row) as? FileTreeNode {
            return node.isDirectory ? node.url : node.url.deletingLastPathComponent()
        }
        return currentRoot
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
                    node.children = FileTreeLoader.load(directory: node.url, parent: node)
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
