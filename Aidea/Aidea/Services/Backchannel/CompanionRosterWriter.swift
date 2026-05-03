//
//  CompanionRosterWriter.swift
//  Aidea
//

import Foundation

/// `.aidea/claude/aidea.md` 内のコンパニオン名簿セクションを `CompanionStore.companions[].name` に追従して更新するヘルパ。
/// マーカー (`<!-- aidea:companions:start -->` / `<!-- aidea:companions:end -->`) の内側を 9 行の roster で書き換える。
/// 詳細仕様: docs/specs/backchannels/companion-roster.md
enum CompanionRosterWriter {

    /// roster ブロックの開始マーカー (HTML コメントなので Markdown レンダリング結果には現れない)
    static let markerStart = "<!-- aidea:companions:start -->"

    /// roster ブロックの終了マーカー
    static let markerEnd = "<!-- aidea:companions:end -->"

    /// `.aidea/claude/aidea.md` 内の roster セクションを最新の name に同期する。
    /// - aidea.md が不在なら no-op (BackchannelSetup 未実行 / ユーザ削除)
    /// - マーカーが両方ある場合は内側 9 行を上書き (マーカー外は触らない)
    /// - マーカーが片方/両方ない場合は末尾に推奨セクションを追記 (本文破壊しない)
    /// - 内容が既存と完全一致なら書き込みをスキップ (mtime 更新を回避し FSEvents を発生させない)
    static func writeRoster(projectRoot: URL, companions: [CompanionConfig]) {
        let aideaURL = projectRoot.appending(path: ".aidea/claude/aidea.md")
        guard let existing = try? String(contentsOf: aideaURL, encoding: .utf8) else { return }

        let newContent = render(existing: existing, companions: companions)
        guard newContent != existing else { return }
        try? newContent.write(to: aideaURL, atomically: true, encoding: .utf8)
    }

    /// 既存内容と最新 companions から書き出すべき新内容を生成する純関数。
    /// テスト容易性のため `static` で公開し、ファイル I/O から分離する。
    static func render(existing: String, companions: [CompanionConfig]) -> String {
        let lineEnding = existing.contains("\r\n") ? "\r\n" : "\n"
        let endsWithNewline = existing.hasSuffix("\n")
        let roster = rosterLines(companions: companions, lineEnding: lineEnding)

        if let replaced = replaceBetweenMarkers(in: existing, with: roster, lineEnding: lineEnding) {
            return replaced
        }
        return appendRosterSection(
            to: existing,
            rosterLines: roster,
            lineEnding: lineEnding,
            endsWithNewline: endsWithNewline
        )
    }

    /// companions を index 昇順で並べ、各行を `- <index>: <name>` 形式で連結する
    private static func rosterLines(companions: [CompanionConfig], lineEnding: String) -> String {
        let sorted = companions.sorted { $0.index < $1.index }
        return sorted.map { "- \($0.index): \($0.name)" }.joined(separator: lineEnding)
    }

    /// マーカー両方が存在する場合、内側を新 roster で置き換えた文字列を返す。マーカーが欠落していれば nil
    private static func replaceBetweenMarkers(
        in existing: String,
        with rosterLines: String,
        lineEnding: String
    ) -> String? {
        guard let startRange = existing.range(of: markerStart),
              let endRange = existing.range(of: markerEnd, range: startRange.upperBound..<existing.endIndex)
        else { return nil }

        let prefix = existing[..<startRange.upperBound]
        let suffix = existing[endRange.lowerBound...]
        return "\(prefix)\(lineEnding)\(rosterLines)\(lineEnding)\(suffix)"
    }

    /// マーカーが欠落している場合、ファイル末尾に推奨 roster セクションを追記する
    private static func appendRosterSection(
        to existing: String,
        rosterLines: String,
        lineEnding: String,
        endsWithNewline: Bool
    ) -> String {
        var result = existing
        if !endsWithNewline { result += lineEnding }
        result += lineEnding
        result += "## ワークスペースのコンパニオン一覧"
        result += lineEnding
        result += lineEnding
        result += "ハンドオフ (handoff.md) で `to` に name を指定したいときは、下の一覧から名前を引いてね。"
        result += lineEnding
        result += lineEnding
        result += "> この一覧は Aidea が自動で書き換えるよ。直接編集しても上書きされちゃうから、"
        result += lineEnding
        result += "> 名前を変えたいときはヘッダのアイコン下の名前ラベルをクリックして編集してね。"
        result += lineEnding
        result += lineEnding
        result += markerStart
        result += lineEnding
        result += rosterLines
        result += lineEnding
        result += markerEnd
        result += lineEnding
        return result
    }
}
