//
//  AppDelegate.swift
//  Aidea
//

import AppKit

/// アプリ全体のライフサイクル制御。
/// 1 プロセス = 1 ウィンドウ = 1 リポジトリ (ADR 0030) のため、ウィンドウを閉じたら
/// プロセスも終了させる (ビューだけ消えてプロセスが残る紛らわしい状態を防ぐ)。
/// 終了時の排他ロック解放は AideaApp の willTerminate オブザーバが担う。
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 最後のウィンドウを閉じたらアプリを終了する
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
