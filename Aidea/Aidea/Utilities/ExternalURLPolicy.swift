//
//  ExternalURLPolicy.swift
//  Aidea
//

import Foundation

/// URL を「アプリ内で扱う / 確認してから外部アプリに渡す / 拒否する」に振り分ける scheme 許可リスト。
/// Web タブのナビゲーション・ターミナルのリンククリック・Chrome 起動・workspace.json 復元で共用する (issue #294)。
/// 外部から来た URL (Web ページ・PTY 出力・リポジトリ同梱の設定) を確認なしに LaunchServices へ渡すと、
/// 任意の URL scheme ハンドラやアプリバンドルが起動できてしまうため、判定をここに集約する。
enum ExternalURLPolicy {
    /// WKWebView 内でのナビゲーションの扱い
    enum WebNavigationDecision: Equatable {
        /// WebKit にそのまま読み込ませる
        case allow
        /// ユーザが自分でリンクを押した場合に限り、確認後に OS 既定アプリで開く
        case confirmExternal
        /// 読み込みも外部起動もしない
        case reject
    }

    /// ターミナル出力中のリンククリックの扱い
    enum TerminalLinkAction: Equatable {
        /// Web ツールで開く (http / https)
        case openWeb
        /// アプリ内 Preview で開く (file: のうち通常ファイル)
        case openPreview(URL)
        /// 実際のリンク先を見せて確認してから OS 既定アプリで開く
        case confirmExternal
        /// 何もしない
        case reject
    }

    /// WKWebView が自前で読み込める scheme。これ以外は WebKit が LaunchServices に渡してしまう。
    /// data: は WebKit 内部で完結し外部ハンドラを起動しないため許可する。
    static let webViewSchemes: Set<String> = ["http", "https", "about", "blob", "data"]

    /// 確認があっても外部アプリへ渡さない scheme。
    /// file: は LaunchServices 経由でアプリバンドルやスクリプトを直接起動できるため常に拒否する。
    static let neverExternalSchemes: Set<String> = ["file"]

    /// http / https で host を持つ URL か (Web タブ復元・Chrome 起動・外部ブラウザで開く際の条件)
    static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        guard let host = url.host(), !host.isEmpty else { return false }
        return true
    }

    /// WKWebView のナビゲーション要求を判定する。
    /// `userInitiated` は「メインフレームでユーザがリンクを押した」場合のみ true を渡すこと。
    /// ページのスクリプトや iframe が勝手に起こした外部 scheme 遷移は確認ダイアログすら出さずに捨てる。
    static func webNavigation(_ url: URL, userInitiated: Bool) -> WebNavigationDecision {
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else { return .reject }
        if webViewSchemes.contains(scheme) { return .allow }
        if neverExternalSchemes.contains(scheme) { return .reject }
        return userInitiated ? .confirmExternal : .reject
    }

    /// ターミナルのリンククリックを判定する。
    /// file: は通常ファイルのみ Preview に回し、ディレクトリ・バンドル・存在しないパスは拒否する。
    static func terminalLink(_ url: URL, fileManager: FileManager = .default) -> TerminalLinkAction {
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else { return .reject }
        if scheme == "http" || scheme == "https" {
            return isWebURL(url) ? .openWeb : .reject
        }
        if scheme == "file" {
            // リモートホスト付きの file: (file://server/...) は扱わない
            if let host = url.host(), !host.isEmpty, host != "localhost" { return .reject }
            let resolved = url.resolvingSymlinksInPath()
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: resolved.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else { return .reject }
            return .openPreview(resolved)
        }
        if neverExternalSchemes.contains(scheme) { return .reject }
        return .confirmExternal
    }
}
