//
//  WorkspaceState.swift
//  Aidea
//

import Foundation
import Observation

/// アプリ全体のワークスペース状態。Phase 1 では projectRoot のみを集中管理する。
/// 選択ファイルなどの "ツール固有の状態" は各 ToolState に置き、ここには持たない。
@Observable
final class WorkspaceState {
    /// 現在開いているプロジェクトのルートディレクトリ
    var projectRoot: URL?

    private static let projectRootKey = "aidea.projectRoot"

    /// UserDefaults から前回の projectRoot を復元する
    init() {
        if let path = UserDefaults.standard.string(forKey: Self.projectRootKey),
           FileManager.default.fileExists(atPath: path) {
            self.projectRoot = URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    /// projectRoot を更新して UserDefaults にも保存する
    func setProjectRoot(_ url: URL) {
        self.projectRoot = url
        UserDefaults.standard.set(url.path, forKey: Self.projectRootKey)
    }
}
