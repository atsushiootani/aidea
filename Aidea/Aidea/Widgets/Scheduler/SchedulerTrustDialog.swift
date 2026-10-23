//
//  SchedulerTrustDialog.swift
//  Aidea
//

import AppKit

/// プロジェクトの scheduler.json を承認するかを尋ねるモーダルダイアログ (issue #293)。
/// 実行されるジョブ (トリガー / 送信先 / 送信する内容そのもの) を一覧で見せ、
/// 「承認して有効にする」を押したときだけ true を返す。既定ボタンは安全側の「承認しない」。
/// docs/specs/widgets/scheduler.md 参照。
enum SchedulerTrustDialog {

    /// モーダルでダイアログを表示する。
    /// - Parameters:
    ///   - projectRoot: 設定ファイルを持つワークスペース (フルパスを表示する)
    ///   - jobs: 承認対象の有効なジョブ一覧
    /// - Returns: 承認されたら true
    @MainActor
    static func show(projectRoot: URL, jobs: [SchedulerConfig.Job]) -> Bool {
        let alert = NSAlert()
        alert.messageText = "スケジューラのジョブを承認しますか？"
        alert.informativeText = """
            このワークスペースの設定ファイルに、自動で実行されるジョブがあります。
            \(projectRoot.standardizedFileURL.path)/.aidea/config/scheduler.json

            承認すると、Terminal ジョブはシェルコマンドとして、Claude ジョブはプロンプトとして送信されます。\
            自分で書いた覚えのない内容なら承認しないでください。内容が変わると再度確認します。
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "承認しない")
        let approveButton = alert.addButton(withTitle: "承認して有効にする")
        approveButton.keyEquivalent = ""

        let width: CGFloat = 460
        let height: CGFloat = 220
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = NSFont.userFixedPitchFont(ofSize: NSFont.smallSystemFontSize)
            ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        textView.string = summary(of: jobs)
        // 長いコマンドを折り返さずに見せる (折り返しで末尾の不審な部分が目立たなくならないように)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false

        scrollView.documentView = textView
        alert.accessoryView = scrollView

        return alert.runModal() == .alertSecondButtonReturn
    }

    /// ダイアログ本文用に、ジョブごとの状態・トリガー・送信先・送信内容を並べた文字列を作る。
    /// 送信内容は改行・タブ以外の制御文字を `\u{XX}` 形式で可視化する (端末制御シーケンスを隠せないように)。
    static func summary(of jobs: [SchedulerConfig.Job]) -> String {
        jobs.map { job in
            let state = job.isEnabled ? "有効" : "無効"
            let target: String
            switch job.target {
            case .claude(let index):
                target = "Claude Companion \(index + 1)"
            case .terminal(let title):
                if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                    target = "Terminal「\(visible(title))」"
                } else {
                    target = "Terminal (新規)"
                }
            }
            let prompt = visible(job.prompt)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { "    " + $0 }
                .joined(separator: "\n")
            return """
                [\(state)] \(visible(job.displayName))
                  トリガー: \(visible(job.triggerLabel))
                  送信先: \(target)
                  送信内容:
                \(prompt)
                """
        }
        .joined(separator: "\n\n")
    }

    /// 改行・タブ以外の制御文字 (ESC / CR / BEL 等) と不可視の書式文字を `\u{XX}` 表記に置き換える。
    static func visible(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            let category = scalar.properties.generalCategory
            if scalar != "\n", scalar != "\t", category == .control || category == .format {
                result += "\\u{" + String(scalar.value, radix: 16, uppercase: true) + "}"
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}
