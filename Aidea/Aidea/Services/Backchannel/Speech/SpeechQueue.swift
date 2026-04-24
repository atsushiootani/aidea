//
//  SpeechQueue.swift
//  Aidea
//

import Foundation
import AVFoundation
import Observation

/// テキストをキューに積み、VOICEVOX で順番に音声再生するキュー。
@Observable
final class SpeechQueue: NSObject, AVAudioPlayerDelegate {
    /// キュー要素: 本文と (任意の) スピーカーID、送信元 Companion index
    private struct Item {
        let text: String
        let speakerId: Int?
        /// 送信元 Companion の index (0..8)。読み上げ中 UI (issue #45) でもこの値が使われる
        let companionIndex: Int?
    }

    var isSpeaking: Bool = false

    /// 現在 VOICEVOX で再生中の speech の送信元 companionIndex (issue #45)。
    /// CompanionView がこの値を監視して笑顔表情 + heart.fill オーバーレイに切り替える。
    /// キューが空 / 再生完了で nil に戻す。
    var currentlySpeakingIndex: Int?

    private var queue: [Item] = []
    private var player: AVAudioPlayer?
    private var isProcessing = false

    /// テキストをキューに追加する。再生中でなければ即座に再生開始。
    /// speakerId が nil の場合は VoicevoxService のデフォルトスピーカーを使用する。
    /// companionIndex は送信元 Companion (0..8)。読み上げ自体には使わないが足場として受け取る。
    func enqueue(_ text: String, speakerId: Int? = nil, companionIndex: Int? = nil) {
        queue.append(Item(text: text, speakerId: speakerId, companionIndex: companionIndex))
        processNext()
    }

    /// キューをクリアして再生を停止する
    func clear() {
        queue.removeAll()
        player?.stop()
        player = nil
        isSpeaking = false
        isProcessing = false
        currentlySpeakingIndex = nil
    }

    private func processNext() {
        guard !isProcessing, !queue.isEmpty else {
            if queue.isEmpty {
                currentlySpeakingIndex = nil
            }
            return
        }
        isProcessing = true
        isSpeaking = true
        let item = queue.removeFirst()
        // 再生開始直前に発信元 Companion をセット (issue #45)。
        // VOICEVOX 合成 → AVAudioPlayer 再生の一連が完了 (or 失敗) するまでこの値を維持する。
        currentlySpeakingIndex = item.companionIndex

        Task {
            do {
                let wavData = try await VoicevoxService.synthesize(item.text, speaker: item.speakerId)
                await MainActor.run {
                    playWav(wavData)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    isSpeaking = false
                    currentlySpeakingIndex = nil
                    processNext()
                }
            }
        }
    }

    /// WAV データを AVAudioPlayer で再生する
    private func playWav(_ data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.play()
        } catch {
            isProcessing = false
            isSpeaking = false
            currentlySpeakingIndex = nil
            processNext()
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isProcessing = false
        if queue.isEmpty {
            isSpeaking = false
            currentlySpeakingIndex = nil
        }
        processNext()
    }
}
