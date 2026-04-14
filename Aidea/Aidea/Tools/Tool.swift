//
//  Tool.swift
//  Aidea
//

import Foundation
import AppKit
import CoreTransferable
import UniformTypeIdentifiers

/// 機能の種別を表す Tool。Window 内のすべての Session はいずれかの Tool に属する。
enum Tool: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case filer
    case kit
    case terminal
    case claude
    case web
    case preview
    case git
    case gitDiff

    var id: String { rawValue }

    /// タブヘッダ等に表示する人間向け名前
    var displayName: String {
        switch self {
        case .filer:    return "Files"
        case .kit:      return "Kit"
        case .terminal: return "Terminal"
        case .claude:   return "Claude"
        case .web:      return "Web"
        case .preview:  return "Preview"
        case .git:      return "Git"
        case .gitDiff:  return "Diff"
        }
    }

    /// タブヘッダのアイコンに使う SF Symbols 名
    var systemImageName: String {
        switch self {
        case .filer:    return "folder"
        case .kit:      return "shippingbox"
        case .terminal: return "apple.terminal"
        case .claude:   return "bubble.left.and.text.bubble.right"
        case .web:      return "globe"
        case .preview:  return "doc.text.magnifyingglass"
        case .git:      return "arrow.triangle.branch"
        case .gitDiff:  return "doc.text.below.ecg"
        }
    }
}

/// Session の一意 ID。Window 内で 1 個の Session 実体を識別する。
/// 同じ Tool 種別でも instance が違えば別の Session。
struct SessionID: Hashable, Codable, Sendable {
    let tool: Tool
    let instance: Int

    init(_ tool: Tool, instance: Int = 0) {
        self.tool = tool
        self.instance = instance
    }
}

/// Session の内部状態を表すプロトコル。Tool 固有のデータとライフサイクルを定義する。
/// focusableView は Session クラスに移動済み (SessionState からは分離)。
protocol SessionState: AnyObject {
    /// このセッションがアクティブになったとき呼ばれる。
    /// フォーカス制御やデータリロード等、Tool 固有の活性化処理を実装する。
    func didBecomeActive(session: Session)

    /// このセッションが非アクティブになったとき呼ばれる。
    func didResignActive(session: Session)

    /// session.focusableView が変更されたとき呼ばれる。
    /// pendingActivation 等、focusableView の遅延セットに対応する処理を実装する。
    func onFocusableViewChanged(session: Session, view: NSView?)

    /// 現在の Scene 識別子を返す
    func currentScene() -> String?

    /// デフォルトのレコメンドプロンプトを返す（永続化されていない場合のフォールバック）
    func recommendedPrompts() -> [String]
}

extension SessionState {
    func didBecomeActive(session: Session) {}
    func didResignActive(session: Session) {}
    func onFocusableViewChanged(session: Session, view: NSView?) {}
    func currentScene() -> String? { nil }
    func recommendedPrompts() -> [String] { [] }
}

/// Tab のドラッグ&ドロップのために SessionID を Transferable にする。
/// ペイロードは "<tool>:<instance>" 形式の文字列 (Swift 6 の Sendable 要件を回避)。
extension SessionID {
    /// D&D 用の文字列表現
    var stringRepresentation: String { "\(tool.rawValue):\(instance)" }

    /// 文字列から復元するイニシャライザ
    init?(stringRepresentation string: String) {
        let parts = string.split(separator: ":")
        guard parts.count == 2,
              let tool = Tool(rawValue: String(parts[0])),
              let instance = Int(parts[1]) else { return nil }
        self.init(tool, instance: instance)
    }
}

extension SessionID: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation<SessionID, String>(
            exporting: { $0.stringRepresentation },
            importing: { SessionID(stringRepresentation: $0) ?? SessionID(.filer) }
        )
    }
}
