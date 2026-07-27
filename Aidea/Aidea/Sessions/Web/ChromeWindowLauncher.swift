//
//  ChromeWindowLauncher.swift
//  Aidea
//

import AppKit
import Foundation

/// Web タブの表示領域と同じ位置・サイズで Google Chrome の新規ウィンドウを開く。
/// WKWebView (Safari 相当) が非対応と判定するサイトを、Web タブから離れた感覚を出さずに
/// 実ブラウザで開き直すための導線 (issue #272 / ADR 0041)。
/// `WorkspaceLauncher` と同じ `open --args` の subprocess 起動パターンを踏襲する。
enum ChromeWindowLauncher {
    private static let chromeBundleIdentifier = "com.google.Chrome"

    /// Google Chrome がインストールされているか
    static var isChromeInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: chromeBundleIdentifier) != nil
    }

    /// `screenRect` (AppKit 座標系: 主画面左下原点・Y 上向き) と同じ位置・サイズの
    /// 新規 Chrome ウィンドウを開いて `url` を読み込む。呼び出し前に `isChromeInstalled` を確認すること。
    static func open(_ url: URL, matching screenRect: NSRect) {
        guard let primaryScreenHeight = NSScreen.screens.first?.frame.height else { return }
        // Chrome の --window-position / --window-size は主画面左上原点・Y 下向きを期待するため変換する
        let topLeftX = Int(screenRect.origin.x.rounded())
        let topLeftY = Int((primaryScreenHeight - screenRect.origin.y - screenRect.height).rounded())
        let width = Int(screenRect.width.rounded())
        let height = Int(screenRect.height.rounded())

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-na", "Google Chrome", "--args",
            "--new-window",
            "--window-position=\(topLeftX),\(topLeftY)",
            "--window-size=\(width),\(height)",
            url.absoluteString,
        ]
        // 起動失敗は致命的でないためログのみ残す (WorkspaceLauncher と同じ個人アプリ方針)
        do {
            try process.run()
        } catch {
            NSLog("[Aidea] Chrome 起動に失敗: \(error.localizedDescription)")
        }
    }
}
