//
//  CommandsSessionState.swift
//  Aidea
//

import Foundation
import Observation

/// Commands Session の内部状態。Loader と選択・グループ開閉を保持する。
@Observable
final class CommandsSessionState: SessionState {
    let workspace: WorkspaceState
    let loader = CommandsLoader()
    var selection: Command.ID?
    var expanded: Set<String> = []

    init(workspace: WorkspaceState) {
        self.workspace = workspace
    }
}
