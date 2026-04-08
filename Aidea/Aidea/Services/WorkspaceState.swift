//
//  WorkspaceState.swift
//  Aidea
//

import Foundation
import Observation

/// アプリ全体のワークスペース状態を保持する Observable オブジェクト。
/// projectRoot / selectedFile を変更すると関連 View が自動更新される。
@Observable
final class WorkspaceState {
    /// 現在開いているプロジェクトのルートディレクトリ
    var projectRoot: URL?

    /// ファイラで選択中のファイル (右ペイン Preview に表示する対象)
    var selectedFile: URL?

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
        self.selectedFile = nil
        UserDefaults.standard.set(url.path, forKey: Self.projectRootKey)
    }
}
