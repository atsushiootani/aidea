//
//  RecommendState.swift
//  Aidea
//

import Foundation
import Observation

/// レコメンドモードの状態管理。コンパニオンへのプロンプト選択 UI を制御する。
@Observable
final class RecommendState {
    var isActive: Bool = false
    var selectedCompanionIndex: Int = 0
    var selectedPromptIndex: Int = 0
    var prompts: [String] = []

    /// レコメンドモードを開始する
    func activate(prompts: [String], companionIndex: Int = 0) {
        guard !prompts.isEmpty else { return }
        self.prompts = prompts
        self.selectedCompanionIndex = companionIndex
        self.selectedPromptIndex = 0
        self.isActive = true
    }

    /// レコメンドモードを終了する
    func deactivate() {
        isActive = false
        prompts = []
    }

    /// 選択中のプロンプトを返す
    var selectedPrompt: String? {
        guard selectedPromptIndex >= 0, selectedPromptIndex < prompts.count else { return nil }
        return prompts[selectedPromptIndex]
    }

    /// プロンプト選択を上に移動（ループ）
    func moveUp() {
        selectedPromptIndex = (selectedPromptIndex - 1 + prompts.count) % prompts.count
    }

    /// プロンプト選択を下に移動（ループ）
    func moveDown() {
        selectedPromptIndex = (selectedPromptIndex + 1) % prompts.count
    }

    /// コンパニオン選択を左に移動（ループ）
    func moveLeft() {
        let count = CompanionIconPresets.imageIcons.count
        selectedCompanionIndex = (selectedCompanionIndex - 1 + count) % count
    }

    /// コンパニオン選択を右に移動（ループ）
    func moveRight() {
        let count = CompanionIconPresets.imageIcons.count
        selectedCompanionIndex = (selectedCompanionIndex + 1) % count
    }
}
