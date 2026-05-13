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
    /// `.git/info/` が存在しない (非 git プロジェクト) 場合は追記をスキップする。
    /// 既に存在する場合は何もしない。
    private static func ensureAideaDirectory(at projectRoot: URL) {
        let fm = FileManager.default
        let aideaDir = projectRoot.appending(path: ".aidea", directoryHint: .isDirectory)
        let jaDir = aideaDir.appending(path: "ja", directoryHint: .isDirectory)

        // ディレクトリ作成
        try? fm.createDirectory(at: jaDir, withIntermediateDirectories: true)

        // .git/info/exclude にローカル専用 ignore として .aidea/ を追記 (ADR 0026)
        let gitInfoDir = projectRoot.appending(path: ".git/info", directoryHint: .isDirectory)
        guard fm.fileExists(atPath: gitInfoDir.path) else { return }

        let exclude = gitInfoDir.appending(path: "exclude")
        let entry = ".aidea/"
        if fm.fileExists(atPath: exclude.path) {
            if let content = try? String(contentsOf: exclude, encoding: .utf8) {
                let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                if !lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == entry }) {
                    let append = content.hasSuffix("\n") ? entry + "\n" : "\n" + entry + "\n"
                    try? (content + append).write(to: exclude, atomically: true, encoding: .utf8)
                }
            }
        } else {
            try? (entry + "\n").write(to: exclude, atomically: true, encoding: .utf8)
        }
    }
}
