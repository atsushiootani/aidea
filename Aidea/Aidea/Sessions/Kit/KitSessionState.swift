//
//  KitSessionState.swift
//  Aidea
//

import Foundation
import Observation

/// Kit Tool のセクション種別。4 つのリソースカテゴリを表す。
enum KitSection: String, CaseIterable, Identifiable, Hashable {
    case agents
    case skills
    case commands
    case mcps

    var id: String { rawValue }

    /// セクションヘッダーに表示するラベル (大文字)
    var title: String {
        switch self {
        case .agents:   return "AGENTS"
        case .skills:   return "SKILLS"
        case .commands: return "COMMANDS"
        case .mcps:     return "MCP SERVERS"
        }
    }
}

/// Kit Session の内部状態。4 つの Loader と展開状態・選択を保持する。
///
/// Kit View は純 SwiftUI で、`@FocusState` + `.focusable()` で focus を取り、
/// 上下キーでの項目移動は SwiftUI の `.onKeyPress` で実装する。
@Observable
final class KitSessionState: SessionState {
    let workspace: WorkspaceState
    let agentsLoader = AgentsLoader()
    let skillsLoader = SkillsLoader()
    let commandsLoader = CommandsLoader()
    let mcpLoader = McpLoader()

    /// 展開中のセクション集合 (初期は全て展開)
    var expandedSections: Set<KitSection> = Set(KitSection.allCases)
    /// 展開中のサブグループキー集合 ("section.prefix" 形式)
    var expandedGroups: Set<String> = []
    /// 選択中の項目キー (`section:id`)
    var selection: String?
    /// Kit がアクティブかどうか。KitSessionView が `@FocusState` と連動させる。
    var isActive: Bool = false

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }

    /// Kit は純 SwiftUI 系 Session のため isActive フラグで SwiftUI 側に通知するだけ。
    /// SwiftUI の `.focused($isActive)` バインドが内部 NSView の firstResponder 出し入れを自動処理する。
    func didBecomeActive(session: Session) {
        isActive = true
    }

    func didResignActive(session: Session) {
        isActive = false
    }
}
