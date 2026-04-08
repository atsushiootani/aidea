//
//  FileTreeView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// プロジェクトルート配下のファイルツリーを NSOutlineView で表示する View。
/// SwiftUI からは NSViewControllerRepresentable 経由で利用する。
struct FileTreeView: NSViewControllerRepresentable {
    @Environment(WorkspaceState.self) private var workspace

    func makeNSViewController(context: Context) -> FileTreeViewController {
        let vc = FileTreeViewController()
        vc.workspace = workspace
        vc.reload()
        return vc
    }

    func updateNSViewController(_ vc: FileTreeViewController, context: Context) {
        // projectRoot が変わっていたら全リロード
        if vc.currentRoot != workspace.projectRoot {
            vc.reload()
        }
    }
}

/// NSOutlineView を保持する NSViewController。データソース・デリゲート・ファイル監視を兼ねる。
final class FileTreeViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var workspace: WorkspaceState?
    /// 現在表示中のルート (差分検知用)
    var currentRoot: URL?

    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let watcher = FileWatcher()
    private var rootNodes: [FileTreeNode] = []
    /// FSEvents 通知のデバウンス用
    private var reloadWorkItem: DispatchWorkItem?
    /// 監視対象から除外するディレクトリ名 (頻繁に書き換わるため)
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

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        self.view = scrollView
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
        // FSEvents 監視を張り直す。除外ディレクトリ配下の通知は無視する。
        watcher.start(path: root.path) { [weak self] paths in
            guard let self = self else { return }
            // 除外パスのみの通知ならスキップ
            let relevant = paths.filter { path in
                !Self.excludedDirs.contains(where: { path.contains("/\($0)/") || path.hasSuffix("/\($0)") })
            }
            if relevant.isEmpty { return }
            // デバウンス: 200ms 待って連続変更をまとめる
            self.reloadWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.handleFileSystemChange()
            }
            self.reloadWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        }
    }

    /// FSEvents 通知を受けたときの処理。展開済みノードの子だけを差分なく再読み込みする。
    private func handleFileSystemChange() {
        guard let root = currentRoot else { return }
        let expandedURLs = collectExpandedURLs()
        rootNodes = FileTreeLoader.load(directory: root).filter { !Self.excludedDirs.contains($0.name) }
        outlineView.reloadData()
        restoreExpandedState(in: rootNodes, expandedURLs: expandedURLs)
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
        workspace?.selectedFile = node.url
    }
}
