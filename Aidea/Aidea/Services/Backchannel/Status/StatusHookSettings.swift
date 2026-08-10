//
//  StatusHookSettings.swift
//  Aidea
//

import Foundation

/// Companion セッション起動時に注入する Claude Code hooks 設定 (`--settings`) を組み立てる。
/// `UserPromptSubmit`/`PreToolUse`/`PostToolUse`/`PostToolUseFailure` → working、
/// `Stop`/`Notification` (informational を除く) → waiting を
/// `.aidea/backchannels/<companion-index>/status-signal.json` に**上書き**するコマンドを登録する
/// (仕様: docs/specs/backchannels/status.md、判断根拠: ADR 0042)。
///
/// hooks の command はここで JSONSerialization を使い組み立てる。手書き文字列結合にしないのは、
/// python スクリプトや絶対パスに含まれ得る `"` `\` を JSON エンコード時に確実にエスケープするため。
enum StatusHookSettings {

    /// 要返答扱いにしない Notification 種別 (ADR 0042: サブエージェント完了等「既に起きたこと」の通知)。
    /// denylist 方式: ここに無い種別 (未知の種別を含む) は安全側 = waiting 扱いにする。
    private static let informationalNotificationTypes = [
        "agent_completed",
        "auth_success",
        "elicitation_complete",
        "elicitation_response",
    ]

    /// `.aidea/backchannels/<companion-index>/hooks-settings.json` を生成し、そのファイル URL を返す。
    /// 生成先ディレクトリが無ければ作成する (このファイルが唯一の書き込み元になるため、
    /// companion 別ディレクトリの事前作成は ADR 0024 の「使わない Companion のディレクトリを
    /// 空作成しない」方針と衝突しない — hooks を注入する = このディレクトリに書き込む前提のため)。
    /// 生成に失敗したら nil を返す (呼び出し側は `--settings` 注入をスキップする)。
    static func write(projectRoot: URL, companionIndex: Int) -> URL? {
        let dir = projectRoot.appending(path: ".aidea/backchannels/\(companionIndex)")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            NSLog("[Aidea] status hooks: failed to create \(dir.path): \(error)")
            return nil
        }
        let signalURL = dir.appending(path: "status-signal.json")
        guard let json = buildSettingsJSON(signalPath: signalURL.path) else { return nil }
        let settingsURL = dir.appending(path: "hooks-settings.json")
        do {
            try json.write(to: settingsURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("[Aidea] status hooks: failed to write \(settingsURL.path): \(error)")
            return nil
        }
        return settingsURL
    }

    /// `claude` 起動コマンドに追加する `--settings '<path>'` の断片。
    /// PTY にキー入力として送るため、パスは単一引用符でシェルエスケープする
    /// (インライン JSON ではなくファイルパスを渡すことで多重エスケープを避ける、status.md 参照)。
    static func launchArgument(settingsURL: URL) -> String {
        "--settings \(shellSingleQuoted(settingsURL.path))"
    }

    // MARK: - JSON construction

    private static func buildSettingsJSON(signalPath: String) -> String? {
        let workingCommand = writeStateCommand(state: "working", signalPath: signalPath)
        let waitingCommand = writeStateCommand(state: "waiting", signalPath: signalPath)
        let notificationCommand = notificationStateCommand(signalPath: signalPath)

        func entry(_ command: String, matcher: String? = nil) -> [String: Any] {
            var e: [String: Any] = ["hooks": [["type": "command", "command": command]]]
            if let matcher { e["matcher"] = matcher }
            return e
        }

        let settings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [entry(workingCommand)],
                "PreToolUse": [entry(workingCommand, matcher: "")],
                "PostToolUse": [entry(workingCommand, matcher: "")],
                "PostToolUseFailure": [entry(workingCommand, matcher: "")],
                "Stop": [entry(waitingCommand)],
                "Notification": [entry(notificationCommand)],
            ],
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// `printf` で `status-signal.json` を丸ごと上書きする 1 行コマンド (working/waiting 共通)。
    private static func writeStateCommand(state: String, signalPath: String) -> String {
        let payload = "{\"state\":\"\(state)\"}"
        return "printf '%s' \(shellSingleQuoted(payload)) > \(shellSingleQuoted(signalPath))"
    }

    /// `Notification` 専用コマンド。標準入力の hook payload (JSON) から `notification_type` を読み、
    /// informational denylist に該当しなければ waiting を書く。jq 等の追加インストールに頼らず、
    /// macOS 標準の python3 を使う (status.md の境界: 外部ツールの事前インストールを前提にしない)。
    private static func notificationStateCommand(signalPath: String) -> String {
        let denylistLiteral = informationalNotificationTypes
            .map { pythonStringLiteral($0) }
            .joined(separator: ",")
        let script = """
        import json,sys
        try:
            p=json.load(sys.stdin)
        except Exception:
            p={}
        if p.get("notification_type") in {\(denylistLiteral)}:
            sys.exit(0)
        open(\(pythonStringLiteral(signalPath)), "w").write('{"state":"waiting"}')
        """
        return "python3 -c \(shellSingleQuoted(script))"
    }

    // MARK: - Escaping helpers

    /// シェルの単一引用符リテラルとしてエスケープする (`'` → `'\''`)。
    private static func shellSingleQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Python の二重引用符文字列リテラルとしてエスケープする。
    private static func pythonStringLiteral(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
