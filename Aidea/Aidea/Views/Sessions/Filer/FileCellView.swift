//
//  FileCellView.swift
//  Aidea
//

import AppKit

/// Filer の 1 行ぶんのセル。アイコン + 名前に加え、ディレクトリ行では名前の右側に
/// AI 要約を薄く小さい文字で表示する (issue #193)。
/// Filer の横幅は変えず、収まらない要約は末尾 truncate する (フル文はツールチップ)。
/// 名前と要約が競合する場合は要約側が先に縮む (compression resistance の差で表現)。
/// docs/specs/tools/filer.md#showdirectorysummary 参照。
final class FileCellView: NSTableCellView {
    /// ディレクトリ要約ラベル (名前の右、10pt / tertiaryLabelColor)
    let summaryField = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        summaryField.translatesAutoresizingMaskIntoConstraints = false
        summaryField.font = NSFont.systemFont(ofSize: 10)
        summaryField.textColor = .tertiaryLabelColor
        summaryField.lineBreakMode = .byTruncatingTail
        summaryField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(icon)
        addSubview(label)
        addSubview(summaryField)
        imageView = icon
        textField = label
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            summaryField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            summaryField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            summaryField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
