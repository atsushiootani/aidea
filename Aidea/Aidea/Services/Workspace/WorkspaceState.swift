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

    /// 起動引数 `--project-root` で開くべきリポジトリが渡されればそれを採用する。
    /// 引数が無い素起動時は projectRoot を確定せず、MRU ランチャー (WorkspaceLauncherView) を出す。
    init() {
        if let argRoot = Self.launchProjectRoot() {
            self.projectRoot = argRoot
            Self.ensureAideaDirectory(at: argRoot)
        }
    }

    /// 起動引数 `--project-root <path>` から開くべきリポジトリを取り出す。
    /// 新プロセス起動 (WorkspaceLauncher) のときに `open -n --args` 経由で渡される。実在ディレクトリのみ返す。
    static func launchProjectRoot() -> URL? {
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: "--project-root"), idx + 1 < args.count else { return nil }
        let path = args[idx + 1]
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
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
