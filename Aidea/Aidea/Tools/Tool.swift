//
//  Tool.swift
//  Aidea
//

import Foundation

/// 機能の種別を表す Tool。Window 内のすべての Session はいずれかの Tool に属する。
enum Tool: String, CaseIterable, Identifiable, Hashable, Codable {
    case filer
    case skills
    case commands
    case mcps
    case terminal
    case web
    case preview

    var id: String { rawValue }

    /// タブヘッダ等に表示する人間向け名前
    var displayName: String {
        switch self {
        case .filer:    return "Files"
        case .skills:   return "Skills"
        case .commands: return "Commands"
        case .mcps:     return "MCPs"
        case .terminal: return "Terminal"
        case .web:      return "Web"
        case .preview:  return "Preview"
        }
    }

    /// タブヘッダのアイコンに使う SF Symbols 名
    var systemImageName: String {
        switch self {
        case .filer:    return "folder"
        case .skills:   return "star"
        case .commands: return "terminal"
        case .mcps:     return "network"
        case .terminal: return "apple.terminal"
        case .web:      return "globe"
        case .preview:  return "doc.text.magnifyingglass"
        }
    }
}

/// Session の一意 ID。Window 内で 1 個の Session 実体を識別する。
/// 同じ Tool 種別でも instance が違えば別の Session。
struct SessionID: Hashable, Codable {
    let tool: Tool
    let instance: Int

    init(_ tool: Tool, instance: Int = 0) {
        self.tool = tool
        self.instance = instance
    }
}

/// Session の内部状態を表すマーカープロトコル。
/// Phase 4 で永続化エンコーディング用に拡張する想定。
protocol SessionState: AnyObject {}
