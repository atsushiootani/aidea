//
//  BackchannelSetup.swift
//  Aidea
//

import Foundation

/// Backchannel の初期設定を行うユーティリティ。
/// `.aidea/claude/aidea.md` の生成と、`CLAUDE.md` への参照追記を担当する。
enum BackchannelSetup {

    /// Backchannel のセットアップを実行する
    static func setup(projectRoot: URL) {
        generateAideaMd(projectRoot: projectRoot)
        ensureClaudeMdReference(projectRoot: projectRoot)
    }

    /// `.aidea/claude/aidea.md` を生成する（常に最新の内容で上書き）
    private static func generateAideaMd(projectRoot: URL) {
        let claudeDir = projectRoot.appending(path: ".aidea/claude")
        let terminalsDir = projectRoot.appending(path: ".aidea/terminals")
        try? FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: terminalsDir, withIntermediateDirectories: true)

        let content = """
        # Aidea Backchannel 指示

        あなたは Aidea ワークスペース内のターミナルで動作しています。
        以下のルールに従ってください。

        ## 読み上げ (Speech)

        レスポンスの最後に、要点を100文字以内の日本語で要約し、
        以下のファイルに書き出してください:

        .aidea/terminals/speech-{timestamp}.txt

        - {timestamp}: 現在時刻 (YYYYMMDDTHHmmss)
        - 1ファイル1メッセージ（追記ではなく新規作成）
        - VOICEVOXで読み上げるため、英単語はカタカナに変換すること
        - 記号は省略すること
        """

        let fileURL = claudeDir.appending(path: "aidea.md")
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// `CLAUDE.md` に `@.aidea/claude/aidea.md` の参照がなければ追記する
    private static func ensureClaudeMdReference(projectRoot: URL) {
        let claudeMd = projectRoot.appending(path: "CLAUDE.md")
        let reference = "@.aidea/claude/aidea.md"

        guard FileManager.default.fileExists(atPath: claudeMd.path) else { return }

        do {
            let content = try String(contentsOf: claudeMd, encoding: .utf8)
            if content.contains(reference) { return }
            // 末尾に追記
            let updated = content.trimmingCharacters(in: .whitespacesAndNewlines)
                + "\n\n\(reference)\n"
            try updated.write(to: claudeMd, atomically: true, encoding: .utf8)
        } catch {
            // CLAUDE.md の読み書きに失敗しても致命的ではない
        }
    }
}
