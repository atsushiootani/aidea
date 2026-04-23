//
//  BackchannelSetup.swift
//  Aidea
//

import Foundation

/// Backchannel の初期設定を行うユーティリティ。
/// Bundle 内の Backchannels リソース (.md) を `.aidea/claude/` にコピーする。
/// 共有指示書 (`aidea.md` / `speech.md`) は初回のみコピー、コンパニオン指示書 (`companions/<0..8>/instructions.md`) は
/// 既存ファイルを上書きしない方針で毎回確認・補填する (ADR 0022)。
enum BackchannelSetup {

    /// 既知の共有 Backchannel 機能ファイル名（拡張子なし）
    private static let knownFeatures = ["speech", "aidea"]

    /// コンパニオン指示書 Bundle テンプレ名（拡張子なし）
    private static let companionInstructionsTemplate = "companion-instructions"

    /// Backchannel のセットアップを実行する。
    /// - 共有指示書 (`aidea.md` / `speech.md`) は `.aidea/claude/` 不在時のみコピー
    /// - コンパニオン指示書は毎回 9 個分の存在を確認し、不在の index に Bundle テンプレを複製
    static func setup(projectRoot: URL) {
        let claudeDir = projectRoot.appending(path: ".aidea/claude")
        let backchannelsDir = projectRoot.appending(path: ".aidea/backchannels")

        // .aidea/claude/ が無ければ初回セットアップ (共有指示書をコピー)
        if !FileManager.default.fileExists(atPath: claudeDir.path) {
            try? FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: backchannelsDir, withIntermediateDirectories: true)
            copyResources(to: claudeDir)
        }

        // コンパニオン指示書は v8 で追加された機能のため、既存 .aidea/claude/ にも適用する
        ensureCompanionInstructions(projectRoot: projectRoot)
    }

    /// Bundle 内の共有指示書を .aidea/claude/ にコピーする
    private static func copyResources(to destination: URL) {
        for feature in knownFeatures {
            guard let source = Bundle.main.url(forResource: feature, withExtension: "md") else { continue }
            let dest = destination.appending(path: "\(feature).md")
            try? FileManager.default.copyItem(at: source, to: dest)
        }
    }

    /// `.aidea/claude/companions/<0..8>/instructions.md` を Bundle テンプレから生成する。
    /// 既存ファイルは上書きしない (ユーザ編集の保護)。
    private static func ensureCompanionInstructions(projectRoot: URL) {
        guard let template = Bundle.main.url(
            forResource: companionInstructionsTemplate,
            withExtension: "md"
        ) else {
            NSLog("[Aidea] companion-instructions.md template not found in Bundle")
            return
        }
        for index in 0..<CompanionInstructions.companionCount {
            let dest = CompanionInstructions.entrypointURL(projectRoot: projectRoot, index: index)
            if FileManager.default.fileExists(atPath: dest.path) { continue }
            let dir = dest.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: template, to: dest)
        }
    }
}
