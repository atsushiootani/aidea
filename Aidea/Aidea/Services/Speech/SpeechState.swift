//
//  SpeechState.swift
//  Aidea
//

import Foundation
import Observation

/// 読み上げ機能の ON/OFF 状態と、Backchannel ファイル監視 → VOICEVOX 読み上げのフローを管理する。
@Observable
final class SpeechState {
    var isEnabled: Bool = true
    var statusMessage: String = ""
    let queue = SpeechQueue()
    private let watcher = SpeechWatcher()
    private var projectRoot: URL?

    /// プロジェクトルートを設定し、Backchannel のセットアップとファイル監視を開始する
    func start(projectRoot: URL) {
        self.projectRoot = projectRoot
        BackchannelSetup.setup(projectRoot: projectRoot)
        watcher.onSpeechFile = { [weak self] text in
            self?.handleSpeechText(text)
        }
        if isEnabled {
            watcher.start(projectRoot: projectRoot)
        }
        checkVoicevox()
    }

    /// speech ファイルが検知された時の処理
    private func handleSpeechText(_ text: String) {
        guard isEnabled else { return }
        queue.enqueue(text)
    }

    /// VOICEVOX の起動状態を確認してステータスを更新する
    func checkVoicevox() {
        Task {
            let available = await VoicevoxService.isAvailable()
            await MainActor.run {
                statusMessage = available ? "" : "VOICEVOX が起動していません"
            }
        }
    }

    /// トグル操作
    func toggle() {
        isEnabled.toggle()
        if isEnabled {
            if let root = projectRoot {
                watcher.start(projectRoot: root)
            }
            checkVoicevox()
        } else {
            watcher.stop()
            queue.clear()
        }
    }
}
