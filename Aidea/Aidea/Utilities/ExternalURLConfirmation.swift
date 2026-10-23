//
//  ExternalURLConfirmation.swift
//  Aidea
//

import Foundation
import AppKit

/// 外部アプリへ URL を渡す前に、実際の行き先 (URL 全文と起動するアプリ名) を見せて確認する (issue #294)。
/// Web ページやターミナル出力は表示テキストと実際のリンク先が食い違いうるため、確認ダイアログには必ず実 URL を出す。
enum ExternalURLConfirmation {
    /// 確認ダイアログを出し、「開く」が選ばれたときだけ OS 既定アプリで開く。
    /// `window` があればシート、無ければモーダルで表示する。開けるアプリが無い URL は何もしない。
    @MainActor
    static func confirmAndOpen(_ url: URL, in window: NSWindow?) {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            NSSound.beep()
            return
        }
        let appName = FileManager.default.displayName(atPath: appURL.path)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "外部アプリで開きますか?"
        alert.informativeText = "「\(appName)」で次のリンクを開きます。\n\n\(url.absoluteString)"
        alert.addButton(withTitle: "開く")
        alert.addButton(withTitle: "キャンセル")
        // 既定ボタンはキャンセル側にする (Enter の押し間違いで外部起動しないように)
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"

        let handle: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertFirstButtonReturn else { return }
            NSWorkspace.shared.open(url)
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }
}
