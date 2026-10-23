//
//  WorkspaceLauncher.swift
//  Aidea
//

import Foundation
import AppKit

/// 別プロセスとして Aidea を起動し、指定リポジトリを開かせる。
/// 1 プロセス = 1 リポジトリの方針に従い、別リポジトリは常に新プロセスで開く (ADR 0030)。
/// 起動前に同一リポジトリの既存プロセスが無いか lock で確認し、あれば前面化要求だけして起動しない。
/// 詳細: docs/specs/window/multi-instance.md
enum WorkspaceLauncher {
    /// 指定 projectRoot を新しいプロセスで開く。
    /// 既に同一リポジトリを開いているプロセスがあれば、それを前面化して新規起動しない。
    static func openInNewProcess(projectRoot: URL) {
        let normalized = projectRoot.standardizedFileURL
        // 既存プロセスの有無を lock で確認する (読み取りのみ。ここでは奪取しない)
        let lockURL = normalized
            .appending(path: ".aidea", directoryHint: .isDirectory)
            .appending(path: ".instance.lock", directoryHint: .notDirectory)
        if let owner = InstanceLock.readOwner(at: lockURL), InstanceLock.isAlive(owner) {
            InstanceActivationChannel.requestActivation(token: owner.token)
            return
        }
        spawn(projectRoot: normalized)
    }

    /// 外部 (`aidea://open-workspace` URL) からのワークスペースを開く要求を、フルパスを見せて確認する (issue #293)。
    /// URL は Web ページや他アプリから渡せる信頼できない入力のため、ユーザが「開く」を選んだときだけ true。
    /// 存在しないパス / ディレクトリでないパスは確認せず false。
    @MainActor
    static func confirmExternalOpen(projectRoot: URL) -> Bool {
        let path = projectRoot.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            NSLog("[Aidea] open-workspace: ディレクトリが無いため無視: \(path)")
            return false
        }
        let alert = NSAlert()
        alert.messageText = "外部からワークスペースを開く要求がありました"
        alert.informativeText = """
            次のディレクトリをワークスペースとして開きますか？

            \(path)

            心当たりがなければ「キャンセル」を選んでください。
            """
        alert.alertStyle = .warning
        // 既定 (Return) は安全側のキャンセル
        alert.addButton(withTitle: "キャンセル")
        let openButton = alert.addButton(withTitle: "開く")
        openButton.keyEquivalent = ""
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn
    }

    /// `open -n` で自バンドルの新インスタンスを起動し、起動引数で projectRoot を渡す。
    /// `NSWorkspace.OpenConfiguration.arguments` は空配列化する既知不具合があるため、
    /// 引数が確実に渡る `open --args` の経路を使う。
    private static func spawn(projectRoot: URL) {
        let bundlePath = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", "-a", bundlePath, "--args", "--project-root", projectRoot.path]
        // 起動失敗は致命的でないためログのみ残す (個人アプリ方針)
        do {
            try process.run()
        } catch {
            NSLog("[Aidea] 新インスタンス起動に失敗: \(error.localizedDescription)")
        }
    }
}
