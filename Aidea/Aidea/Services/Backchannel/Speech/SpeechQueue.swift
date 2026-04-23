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
    /// キュー要素: 本文と (任意の) スピーカーID
    private struct Item {
        let text: String
        let speakerId: Int?
    }

    var isSpeaking: Bool = false

    private var queue: [Item] = []
    private var player: AVAudioPlayer?
    private var isProcessing = false

    /// テキストをキューに追加する。再生中でなければ即座に再生開始。
    /// speakerId が nil の場合は VoicevoxService のデフォルトスピーカーを使用する。
    func enqueue(_ text: String, speakerId: Int? = nil) {
        queue.append(Item(text: text, speakerId: speakerId))
        processNext()
    }

    /// キューをクリアして再生を停止する
    func clear() {
        queue.removeAll()
        player?.stop()
        player = nil
        isSpeaking = false
        isProcessing = false
    }

    private func processNext() {
        guard !isProcessing, !queue.isEmpty else { return }
        isProcessing = true
        isSpeaking = true
        let item = queue.removeFirst()

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
            processNext()
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isProcessing = false
        if queue.isEmpty {
            isSpeaking = false
        }
        processNext()
    }
}
