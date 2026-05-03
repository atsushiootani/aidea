//
//  String+NaturalOrder.swift
//  Aidea
//

import Foundation

/// Aidea 全 List UI 共通の自然順比較ヘルパ。
/// Filer / Git ファイルツリー / Git diff / Kit など全 List のソート規約を 1 箇所に集約する。
/// 詳細: docs/specs/aspects/sort-order.md
extension String {
    /// Finder 互換の自然順 (`localizedStandardCompare`) で昇順比較する。
    /// 大文字小文字非区別・数値ソート・ロケール依存の自然順を提供する。
    func naturalAscending(_ other: String) -> Bool {
        localizedStandardCompare(other) == .orderedAscending
    }
}
