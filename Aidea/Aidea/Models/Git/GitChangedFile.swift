//
//  GitChangedFile.swift
//  Aidea
//

import Foundation

/// git diff --name-status の 1 行を表すモデル
struct GitChangedFile: Identifiable, Hashable {
    let id: String          // パス (一意)
    let path: String        // 相対パス
    let status: Status
    let isStaged: Bool

    enum Status: String {
        case modified  = "M"
        case added     = "A"
        case deleted   = "D"
        case renamed   = "R"
        case untracked = "?"

        var label: String {
            switch self {
            case .modified:  return "M"
            case .added:     return "A"
            case .deleted:   return "D"
            case .renamed:   return "R"
            case .untracked: return "U"
            }
        }

        var iconName: String {
            switch self {
            case .modified:  return "pencil.circle.fill"
            case .added:     return "plus.circle.fill"
            case .deleted:   return "minus.circle.fill"
            case .renamed:   return "arrow.right.circle.fill"
            case .untracked: return "questionmark.circle.fill"
            }
        }

        var colorName: String {
            switch self {
            case .modified:  return "yellow"
            case .added:     return "green"
            case .deleted:   return "red"
            case .renamed:   return "blue"
            case .untracked: return "green"
            }
        }
    }
}

/// git diff --name-status の出力をパースする
enum GitChangesParser {
    static func parse(_ output: String, staged: Bool = false) -> [GitChangedFile] {
        output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 2)
            guard parts.count >= 2 else { return nil }
            let statusStr = String(parts[0]).prefix(1)
            guard let status = GitChangedFile.Status(rawValue: String(statusStr)) else { return nil }
            let path: String
            if status == .renamed, parts.count >= 3 {
                path = String(parts[2]) // リネーム先
            } else {
                path = String(parts[1])
            }
            return GitChangedFile(id: path, path: path, status: status, isStaged: staged)
        }
    }

    /// 未追跡ファイル一覧をパースする (1行1パス)
    static func parseUntracked(_ output: String) -> [GitChangedFile] {
        output.split(separator: "\n").map { line in
            let path = String(line)
            return GitChangedFile(id: path, path: path, status: .untracked, isStaged: false)
        }
    }
}
