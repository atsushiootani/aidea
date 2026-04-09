//
//  LayoutContainerViewController.swift
//  Aidea
//

import AppKit

/// SwiftUI NSViewControllerRepresentable から単一の子 NSViewController を差し替え可能にするためのコンテナ。
/// 動的レイアウト (SplitLayoutView) で layout tree が変わるたびに新しい root controller を
/// セットできるようにする。
final class LayoutContainerViewController: NSViewController {
    override func loadView() {
        view = NSView()
    }

    /// 唯一の子 view controller。変更時に旧 controller をはずして新しい view を貼る。
    var childController: NSViewController? {
        didSet {
            guard oldValue !== childController else { return }
            if let old = oldValue {
                old.view.removeFromSuperview()
                old.removeFromParent()
            }
            guard let child = childController else { return }
            addChild(child)
            view.addSubview(child.view)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                child.view.topAnchor.constraint(equalTo: view.topAnchor),
                child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }
}
