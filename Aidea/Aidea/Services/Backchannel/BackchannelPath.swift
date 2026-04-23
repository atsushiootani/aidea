//
//  BackchannelPath.swift
//  Aidea
//

import Foundation

/// Backchannel ファイルパス (`.aidea/backchannels/<companion-index>/<type>-*.<ext>`) の
/// 共通パース/検証ユーティリティ。
/// SpeechWatcher / HandoffWatcher 等、Companion index を親ディレクトリ名から抽出する
/// 責務を 1 箇所に集約し、検証ルール (0..8 の整数) を SSoT にする (ADR 0024)。
enum BackchannelPath {

    /// Companion index の有効範囲 (ADR 0022 で 9 枠固定)
    static let validIndexRange: ClosedRange<Int> = 0...8

    /// ファイル URL の親ディレクトリ名を読み取り、Companion index の有効範囲 (0..8) の整数なら返す。
    /// それ以外 (範囲外の数字 / 文字列ディレクトリ / `.aidea/backchannels/` 直下) は nil。
    static func extractCompanionIndex(from fileURL: URL) -> Int? {
        let parent = fileURL.deletingLastPathComponent().lastPathComponent
        guard let index = Int(parent), validIndexRange.contains(index) else { return nil }
        return index
    }
}
