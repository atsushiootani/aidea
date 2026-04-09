//
//  SkillsSessionState.swift
//  Aidea
//

import Foundation
import Observation

/// Skills Session の内部状態。Loader と選択・グループ開閉を保持する。
@Observable
final class SkillsSessionState: SessionState {
    let workspace: WorkspaceState
    let loader = SkillsLoader()
    var selection: Skill.ID?
    var expanded: Set<String> = []

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }
}
