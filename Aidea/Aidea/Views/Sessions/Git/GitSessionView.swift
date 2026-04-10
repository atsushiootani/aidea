//
//  GitSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// Git Session の SwiftUI ラッパ。変更ファイル一覧を NSOutlineView で表示する。
struct GitSessionView: NSViewControllerRepresentable {
    let session: Session
    let state: GitSessionState
    @Environment(WorkspaceState.self) private var workspace

    func makeNSViewController(context: Context) -> GitFileListViewController {
        let vc = GitFileListViewController()
        vc.state = state
        vc.session = session
        vc.loadViewIfNeeded()
        vc.reload()
        session.focusableView = vc.outlineView
        return vc
    }

    func updateNSViewController(_ vc: GitFileListViewController, context: Context) {
        // モード変更時に再読み込み
    }
}

/// Git 変更ファイル一覧の NSViewController
final class GitFileListViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    var state: GitSessionState?
    var session: Session?
    let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let watcher = FileWatcher()
    private var reloadWorkItem: DispatchWorkItem?

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
        outlineView.target = self
        outlineView.doubleAction = #selector(handleDoubleClick)

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        // モード切替ピッカー
        let picker = NSSegmentedControl(labels: GitMode.allCases.map(\.rawValue),
                                        trackingMode: .selectOne,
                                        target: self,
                                        action: #selector(modeChanged(_:)))
        picker.selectedSegment = 0
        picker.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(picker)
        container.addSubview(scrollView)
        picker.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            picker.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            picker.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        self.view = container

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
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
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
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? GitFileTreeNode,
              !node.isDirectory else { return }
        openDiff(for: node)
    }

    private func openDiff(for node: GitFileTreeNode) {
        guard let registry = state?.registry, let mode = state?.mode else { return }
        let isUntracked = node.status == .untracked
        registry.openGitDiff(for: node.relativePath, mode: mode, isUntracked: isUntracked, isStaged: node.isStaged)
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
        let id = NSUserInterfaceItemIdentifier("GitCell")
        let cell: NSTableCellView
        if let recycled = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = recycled
        } else {
            cell = NSTableCellView()
            cell.identifier = id
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
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        cell.textField?.stringValue = node.name
        cell.textField?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        if node.isDirectory {
            cell.imageView?.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
            cell.imageView?.contentTintColor = .secondaryLabelColor
        } else if let status = node.status {
            cell.imageView?.image = NSImage(systemSymbolName: status.iconName, accessibilityDescription: nil)
            switch status {
            case .modified:  cell.imageView?.contentTintColor = .systemOrange
            case .added:     cell.imageView?.contentTintColor = .systemGreen
            case .deleted:   cell.imageView?.contentTintColor = .systemRed
            case .renamed:   cell.imageView?.contentTintColor = .systemBlue
            case .untracked: cell.imageView?.contentTintColor = .systemGreen
            }
        }
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? GitFileTreeNode else { return }
        state?.selectedPath = node.relativePath
    }
}
