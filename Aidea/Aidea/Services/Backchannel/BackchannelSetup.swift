//
//  BackchannelSetup.swift
//  Aidea
//

import Foundation

/// Backchannel の初期設定を行うユーティリティ。
/// Bundle 内の Backchannels リソース (.md) を `.aidea/claude/` にコピーする。
/// 初回セットアップ済みのディレクトリではスキップする。
enum BackchannelSetup {

    /// 既知の Backchannel 機能ファイル名（拡張子なし）
    private static let knownFeatures = ["speech", "aidea"]

    /// Backchannel のセットアップを実行する（初回のみ）
    static func setup(projectRoot: URL) {
        let claudeDir = projectRoot.appending(path: ".aidea/claude")
        let backchannelsDir = projectRoot.appending(path: ".aidea/backchannels")

        // .aidea/claude/ が既に存在すればセットアップ済み
        if FileManager.default.fileExists(atPath: claudeDir.path) { return }

        try? FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: backchannelsDir, withIntermediateDirectories: true)

        copyResources(to: claudeDir)
    }

    /// Bundle 内の Backchannels リソースを .aidea/claude/ にコピーする
    private static func copyResources(to destination: URL) {
        for feature in knownFeatures {
            guard let source = Bundle.main.url(forResource: feature, withExtension: "md") else { continue }
            let dest = destination.appending(path: "\(feature).md")
            try? FileManager.default.copyItem(at: source, to: dest)
        }
    }
}
