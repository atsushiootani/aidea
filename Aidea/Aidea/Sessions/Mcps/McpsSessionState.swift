//
//  McpsSessionState.swift
//  Aidea
//

import Foundation
import Observation

/// MCPs Session の内部状態。Loader と選択を保持する。
@Observable
final class McpsSessionState: SessionState {
    let loader = McpLoader()
    var selection: McpServer.ID?
}
