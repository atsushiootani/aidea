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
    /// clear() のたびに進む世代番号。OFF (clear) 時点で VOICEVOX 合成中だった Task の
    /// 結果を ON 後に破棄するために使う。破棄しないと、残った Task が再生中の player を
    /// 上書きして完了 delegate が失われ、キューが恒久的に詰まる (issue #235)。
    private var generation = 0

    /// テキストをキューに追加する。再生中でなければ即座に再生開始。
    /// speakerId が nil の場合は VoicevoxService のデフォルトスピーカーを使用する。
    /// companionIndex は送信元 Companion (0..8)。読み上げ自体には使わないが足場として受け取る。
    func enqueue(_ text: String, speakerId: Int? = nil, companionIndex: Int? = nil) {
        queue.append(Item(text: text, speakerId: speakerId, companionIndex: companionIndex))
        processNext()
    }

    /// キューをクリアして再生を停止する。合成中の Task の結果も以後破棄される (世代番号)
    func clear() {
        generation += 1
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

        let gen = generation
        Task {
            do {
                let wavData = try await VoicevoxService.synthesize(item.text, speaker: item.speakerId)
                await MainActor.run {
                    // 合成中に clear() されていたら結果を破棄する (issue #235)
                    guard gen == generation else { return }
                    playWav(wavData)
                }
            } catch {
                await MainActor.run {
                    guard gen == generation else { return }
                    isProcessing = false
                    isSpeaking = false
                    currentlySpeakingIndex = nil
                    processNext()
                }
            }
        }
    }

    /// WAV データを AVAudioPlayer で再生する。
    /// play() が false の場合は完了 delegate が来ないため、失敗扱いで次へ進む (issue #235)。
    private func playWav(_ data: Data) {
        do {
            let newPlayer = try AVAudioPlayer(data: data)
            newPlayer.delegate = self
            player = newPlayer
            guard newPlayer.play() else {
                skipCurrent()
                return
            }
        } catch {
            skipCurrent()
        }
    }

    /// 現在のエントリを失敗扱いでスキップし、次のエントリへ進む
    private func skipCurrent() {
        player = nil
        isProcessing = false
        isSpeaking = false
        currentlySpeakingIndex = nil
        processNext()
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // delegate の呼び出しスレッドは保証されないため、キュー操作はメインスレッドに寄せる
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isProcessing = false
            if self.queue.isEmpty {
                self.isSpeaking = false
                self.currentlySpeakingIndex = nil
            }
            self.processNext()
        }
    }
}
