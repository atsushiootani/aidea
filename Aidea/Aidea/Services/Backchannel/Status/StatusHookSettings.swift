//
//  StatusHookSettings.swift
//  Aidea
//

import Foundation

/// Companion セッション起動時に注入する Claude Code hooks 設定 (`--settings`) を組み立てる。
/// `UserPromptSubmit` → 作業中、`Stop` / `Notification` (informational を除く) → 要返答 を
/// `.aidea/backchannels/<companion-index>/status.json` に**上書き**するコマンドを登録する
/// (仕様: docs/specs/backchannels/status.md、判断根拠: ADR 0042)。
///
/// ツール実行中のイベント (`PreToolUse`/`PostToolUse`/`PostToolUseFailure`) は登録しない。
/// 書き込み先が 1 ファイルのため、ツール呼び出しのたびに固定文言で上書きすると
/// Claude 自身が書いた説明文がターン中に消えてしまうため (ADR 0042)。
/// 書き込む文言は `.aidea/config/status-labels.json` でカスタマイズでき、生成時に埋め込む。
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
        let labels = StatusLabelsStore(projectRoot: projectRoot).loadConfig()
        let dir = projectRoot.appending(path: ".aidea/backchannels/\(companionIndex)")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            NSLog("[Aidea] status hooks: failed to create \(dir.path): \(error)")
            return nil
        }
        let statusURL = dir.appending(path: "status.json")
        guard let json = buildSettingsJSON(statusPath: statusURL.path, labels: labels) else { return nil }
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

    private static func buildSettingsJSON(statusPath: String, labels: StatusLabelsConfig) -> String? {
        let workingCommand = writeStatusCommand(status: labels.working, statusPath: statusPath)
        let waitingCommand = writeStatusCommand(status: labels.waiting, statusPath: statusPath)
        let notificationCommand = notificationStatusCommand(status: labels.waiting, statusPath: statusPath)

        func entry(_ command: String, matcher: String? = nil) -> [String: Any] {
            var e: [String: Any] = ["hooks": [["type": "command", "command": command]]]
            if let matcher { e["matcher"] = matcher }
            return e
        }

        // ターンの境界のみを登録する。ツール実行中のイベントは Claude の自己申告を
        // 上書きしてしまうため対象外 (ADR 0042)。
        let settings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [entry(workingCommand)],
                "Stop": [entry(waitingCommand)],
                "Notification": [entry(notificationCommand)],
            ],
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// `printf` で `status.json` を丸ごと上書きする 1 行コマンド。
    /// 文言に `"` や `\` が含まれても壊れないよう JSON エンコードして埋め込む。
    private static func writeStatusCommand(status: String, statusPath: String) -> String {
        let payload = jsonStatusPayload(status)
        return "printf '%s' \(shellSingleQuoted(payload)) > \(shellSingleQuoted(statusPath))"
    }

    /// `{"status":"..."}` の JSON 文字列を作る (値のエスケープは JSONSerialization に任せる)。
    private static func jsonStatusPayload(_ status: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: ["status": status]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"status\":\"\"}"
        }
        return json
    }

    /// `Notification` 専用コマンド。標準入力の hook payload (JSON) から `notification_type` を読み、
    /// informational denylist に該当しなければ要返答の文言を書く。jq 等の追加インストールに頼らず、
    /// macOS 標準の python3 を使う (status.md の境界: 外部ツールの事前インストールを前提にしない)。
    private static func notificationStatusCommand(status: String, statusPath: String) -> String {
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
        open(\(pythonStringLiteral(statusPath)), "w").write(\(pythonStringLiteral(jsonStatusPayload(status))))
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
