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
    func activate(prompts: [String]) {
        guard !prompts.isEmpty else { return }
        self.prompts = prompts
        self.selectedCompanionIndex = 0
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

    /// プロンプト選択を上に移動
    func moveUp() {
        if selectedPromptIndex > 0 { selectedPromptIndex -= 1 }
    }

    /// プロンプト選択を下に移動
    func moveDown() {
        if selectedPromptIndex < prompts.count - 1 { selectedPromptIndex += 1 }
    }

    /// コンパニオン選択を左に移動
    func moveLeft() {
        if selectedCompanionIndex > 0 { selectedCompanionIndex -= 1 }
    }

    /// コンパニオン選択を右に移動
    func moveRight() {
        let maxIndex = CompanionIconPresets.imageIcons.count - 1
        if selectedCompanionIndex < maxIndex { selectedCompanionIndex += 1 }
    }
}
