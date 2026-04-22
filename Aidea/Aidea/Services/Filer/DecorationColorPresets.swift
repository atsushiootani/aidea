//
//  DecorationColorPresets.swift
//  Aidea
//

import AppKit

/// デコレーション編集 UI の色列ポップアップで先頭に表示する推奨色プリセット。
/// 「カスタム...」を選ぶと NSColorPanel から自由に色を選び、内部で hex 文字列に正規化して保存する。
///
/// 行背景に塗るときは `applied(for:)` で `alpha 0.2` を掛けて可読性を確保する。
/// 仕様: `docs/specs/tools/filer.md#推奨色`
enum DecorationColorPresets {
    /// プリセットエントリ。`name` が `DecorationRule.color` に保存されるキー名。
    struct Entry {
        let name: String
        let color: NSColor
    }

    static let recommended: [Entry] = [
        Entry(name: "yellow",  color: .systemYellow),
        Entry(name: "orange",  color: .systemOrange),
        Entry(name: "red",     color: .systemRed),
        Entry(name: "pink",    color: .systemPink),
        Entry(name: "purple",  color: .systemPurple),
        Entry(name: "blue",    color: .systemBlue),
        Entry(name: "teal",    color: .systemTeal),
        Entry(name: "green",   color: .systemGreen),
        Entry(name: "brown",   color: .systemBrown),
        Entry(name: "gray",    color: .systemGray)
    ]

    /// `DecorationRule.color` (プリセットキー or hex `#RRGGBB`) を NSColor に解決する。
    /// 不明な値・nil なら nil。
    static func resolve(_ name: String?) -> NSColor? {
        guard let name = name, !name.isEmpty else { return nil }
        if let preset = recommended.first(where: { $0.name == name }) {
            return preset.color
        }
        return Self.colorFromHex(name)
    }

    /// 行背景に塗る用の半透明色を返す (alpha 0.2)。
    static func appliedBackground(for name: String?) -> NSColor? {
        guard let base = resolve(name) else { return nil }
        return base.withAlphaComponent(0.2)
    }

    /// `#RRGGBB` 形式の hex 文字列を NSColor に変換する。失敗したら nil。
    private static func colorFromHex(_ hex: String) -> NSColor? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xff) / 255.0
        let g = CGFloat((v >> 8) & 0xff) / 255.0
        let b = CGFloat(v & 0xff) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    /// NSColor を `#RRGGBB` 形式の hex 文字列に変換する (ユーザがカスタム色を選んだときの保存用)。
    static func hexString(from color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int((srgb.redComponent * 255.0).rounded())
        let g = Int((srgb.greenComponent * 255.0).rounded())
        let b = Int((srgb.blueComponent * 255.0).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
