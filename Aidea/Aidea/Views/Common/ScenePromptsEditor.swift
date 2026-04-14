//
//  ScenePromptsEditor.swift
//  Aidea
//

import AppKit

/// Scene のレコメンドプロンプトとデフォルトコンパニオンを編集する NSView。
/// 左端にデフォルトコンパニオンアイコン、右にプロンプトをタグ風に表示。
final class ScenePromptsEditor: NSView {
    private let scene: String
    private let defaults: [String]
    private let companionButton = NSButton()
    private let stack = NSStackView()
    private let addButton = NSButton(title: "+", target: nil, action: nil)

    init(scene: String, defaults: [String]) {
        self.scene = scene
        self.defaults = defaults
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        // デフォルトコンパニオンアイコン
        companionButton.bezelStyle = .inline
        companionButton.isBordered = false
        companionButton.target = self
        companionButton.action = #selector(selectCompanion)
        companionButton.translatesAutoresizingMaskIntoConstraints = false
        updateCompanionIcon()

        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false

        addButton.bezelStyle = .inline
        addButton.font = .systemFont(ofSize: 11)
        addButton.target = self
        addButton.action = #selector(addPrompt)
        addButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(companionButton)
        addSubview(stack)
        addSubview(addButton)
        NSLayoutConstraint.activate([
            companionButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            companionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            companionButton.widthAnchor.constraint(equalToConstant: 22),
            companionButton.heightAnchor.constraint(equalToConstant: 22),
            stack.leadingAnchor.constraint(equalTo: companionButton.trailingAnchor, constant: 6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.leadingAnchor.constraint(equalTo: stack.trailingAnchor, constant: 4),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            heightAnchor.constraint(equalToConstant: 28),
        ])

        reloadTags()
    }

    /// デフォルトコンパニオンのインデックス
    private var defaultCompanionIndex: Int {
        RecommendStore.defaultCompanionIndex(for: scene)
    }

    /// 現在のプロンプトを取得（永続化 > デフォルト）
    private var prompts: [String] {
        RecommendStore.resolve(scene: scene, defaults: defaults)
    }

    /// コンパニオンアイコンを更新する
    private func updateCompanionIcon() {
        let icons = CompanionIconPresets.imageIcons
        let index = defaultCompanionIndex
        guard index < icons.count else { return }
        let image = NSImage(named: icons[index])
        companionButton.image = image?.resized(to: NSSize(width: 20, height: 20))
        companionButton.toolTip = "デフォルトコンパニオンを変更"
    }

    /// タグを再構築する
    private func reloadTags() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, prompt) in prompts.enumerated() {
            stack.addArrangedSubview(makeTag(prompt, index: index))
        }
    }

    /// プロンプトタグを作成する
    private func makeTag(_ text: String, index: Int) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        container.layer?.cornerRadius = 4

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .controlAccentColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let removeBtn = NSButton(title: "×", target: self, action: #selector(removePrompt(_:)))
        removeBtn.bezelStyle = .inline
        removeBtn.font = .systemFont(ofSize: 9, weight: .bold)
        removeBtn.tag = index
        removeBtn.isBordered = false
        removeBtn.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(removeBtn)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            removeBtn.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 2),
            removeBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            removeBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 22),
        ])
        return container
    }

    @objc private func selectCompanion() {
        let menu = NSMenu()
        let icons = CompanionIconPresets.imageIcons
        for (i, icon) in icons.enumerated() {
            let item = NSMenuItem(title: "Companion \(i + 1)", action: #selector(companionSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            item.image = NSImage(named: icon)?.resized(to: NSSize(width: 16, height: 16))
            if i == defaultCompanionIndex {
                item.state = .on
            }
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: companionButton.bounds.height), in: companionButton)
    }

    @objc private func companionSelected(_ sender: NSMenuItem) {
        RecommendStore.saveDefaultCompanion(scene: scene, index: sender.tag)
        updateCompanionIcon()
    }

    @objc private func addPrompt() {
        let alert = NSAlert()
        alert.messageText = "プロンプトを追加"
        alert.informativeText = "コンパニオンに送るプロンプトを入力してください"
        alert.addButton(withTitle: "追加")
        alert.addButton(withTitle: "キャンセル")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        alert.accessoryView = input
        if alert.runModal() == .alertFirstButtonReturn, !input.stringValue.isEmpty {
            var current = prompts
            current.append(input.stringValue)
            RecommendStore.save(scene: scene, prompts: current)
            reloadTags()
        }
    }

    @objc private func removePrompt(_ sender: NSButton) {
        var current = prompts
        guard sender.tag >= 0, sender.tag < current.count else { return }
        current.remove(at: sender.tag)
        RecommendStore.save(scene: scene, prompts: current)
        reloadTags()
    }
}

/// NSImage リサイズヘルパー
private extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy, fraction: 1.0)
        img.unlockFocus()
        return img
    }
}
