//
//  WorkspaceState.swift
//  Aidea
//

import Foundation
import Observation

/// アプリ全体のワークスペース状態。projectRoot を集中管理する。
/// 選択ファイルなどの "ツール固有の状態" は各 SessionState に置き、ここには持たない。
@Observable
final class WorkspaceState {
    /// 現在開いているプロジェクトのルートディレクトリ
    var projectRoot: URL?

    private static let projectRootKey = "aidea.projectRoot"

    /// UserDefaults から前回の projectRoot を復元する
    init() {
        if let path = UserDefaults.standard.string(forKey: Self.projectRootKey),
           FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            self.projectRoot = url
            Self.ensureAideaDirectory(at: url)
        }
    }

    /// projectRoot を更新して UserDefaults にも保存する
    func setProjectRoot(_ url: URL) {
        self.projectRoot = url
        UserDefaults.standard.set(url.path, forKey: Self.projectRootKey)
        Self.ensureAideaDirectory(at: url)
    }

    /// `.aidea/` と `.aidea/ja/` を作成し、`.git/info/exclude` に `.aidea/` を追記する。
    /// 既に存在する場合は何もしない。共有 `.gitignore` は変更しない (ADR 0026)。
    private static func ensureAideaDirectory(at projectRoot: URL) {
        let fm = FileManager.default
        let aideaDir = projectRoot.appending(path: ".aidea", directoryHint: .isDirectory)
        let jaDir = aideaDir.appending(path: "ja", directoryHint: .isDirectory)

        // ディレクトリ作成
        try? fm.createDirectory(at: jaDir, withIntermediateDirectories: true)

        // .git/info/exclude に .aidea/ を追記 (共有 .gitignore は触らない)
        let gitInfoDir = projectRoot.appending(path: ".git/info", directoryHint: .isDirectory)
        guard fm.fileExists(atPath: gitInfoDir.path) else { return }

        let excludeFile = gitInfoDir.appending(path: "exclude")
        let entry = ".aidea/"
        if fm.fileExists(atPath: excludeFile.path) {
            guard let content = try? String(contentsOf: excludeFile, encoding: .utf8) else { return }
            let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if !lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == entry }) {
                let append = content.hasSuffix("\n") ? entry + "\n" : "\n" + entry + "\n"
                try? (content + append).write(to: excludeFile, atomically: true, encoding: .utf8)
            }
        } else {
            try? (entry + "\n").write(to: excludeFile, atomically: true, encoding: .utf8)
        }
    }
}
