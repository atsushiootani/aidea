//
//  ClosureMenuItem.swift
//  Aidea
//

import AppKit

/// クロージャを保持する NSMenuItem。`+` ボタンや Cmd+T のツール選択メニュー等で利用する。
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, image: NSImage?, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        self.target = self
        self.image = image
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func invoke() {
        handler()
    }
}
