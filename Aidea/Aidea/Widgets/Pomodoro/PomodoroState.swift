//
//  PomodoroState.swift
//  Aidea
//

import Foundation
import Observation

/// ポモドーロタイマーの状態と動作 (1 秒刻みカウントダウン、フェーズ自動遷移)。
/// 永続化はせず、アプリ再起動で常に初期状態 (focus / 1500s / isRunning=false) に戻る。
/// docs/specs/widgets/pomodoro.md 参照。
@MainActor
@Observable
final class PomodoroState {
    var phase: PomodoroPhase = .focus
    var remainingSeconds: Int = PomodoroPhase.focus.initialSeconds
    var isRunning: Bool = false
    /// 残り時間表示の編集モード。true の間は `tick` でカウントダウンを進めない。
    var isEditing: Bool = false

    /// フェーズが自動遷移したときに呼ばれるハンドラ。
    /// AideaApp が SpeechQueue.enqueue を行うフックとして使う (companionIndex = 6)。
    /// 手動 reset では呼ばれない (= 自動遷移時のみ通知)。
    @ObservationIgnored
    var onPhaseTransition: ((PomodoroPhase) -> Void)?

    @ObservationIgnored
    private var timer: Timer?

    /// Start / Pause トグル
    func toggleRun() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    /// 計測開始 (1 秒刻み Timer をスケジュール)
    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTimer()
    }

    /// 一時停止
    func pause() {
        isRunning = false
        invalidateTimer()
    }

    /// 集中フェーズの初期状態に戻す。フェーズ遷移ハンドラは呼ばない (手動 reset のため)。
    func reset() {
        invalidateTimer()
        phase = .focus
        remainingSeconds = phase.initialSeconds
        isRunning = false
    }

    /// 残り時間を直接書き換える (編集確定時)
    func setRemainingSeconds(_ seconds: Int) {
        remainingSeconds = max(0, seconds)
    }

    private func scheduleTimer() {
        invalidateTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// 1 秒経過の処理。編集中はスキップ。0 到達でフェーズ自動遷移。
    private func tick() {
        guard isRunning, !isEditing else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }
        if remainingSeconds == 0 {
            advancePhase()
        }
    }

    /// 次のフェーズへ自動遷移する (連続運用前提で isRunning は維持)
    private func advancePhase() {
        phase = phase.next
        remainingSeconds = phase.initialSeconds
        onPhaseTransition?(phase)
    }
}
