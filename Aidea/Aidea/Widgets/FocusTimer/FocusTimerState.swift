//
//  FocusTimerState.swift
//  Aidea
//

import Foundation
import Observation

/// 没入防止タイマーの状態と動作。設定時間が切れると onExpiry が呼ばれる。
/// 永続化はせず、アプリ再起動で常に初期状態 (30 分 / isRunning=false) に戻る。
/// docs/specs/widgets/focus-timer.md 参照。
@MainActor
@Observable
final class FocusTimerState {
    static let defaultDurationSeconds = 30 * 60

    /// ユーザが設定した計測時間 (秒)。編集確定で更新される。
    var totalSeconds: Int = defaultDurationSeconds
    var remainingSeconds: Int = defaultDurationSeconds
    var isRunning: Bool = false
    var isEditing: Bool = false
    var isExpired: Bool = false

    /// 時間切れ時に呼ばれるハンドラ。AideaApp が読み上げ + frontchannel 送信を行う。
    /// 手動 reset では呼ばれない。
    @ObservationIgnored
    var onExpiry: (() -> Void)?

    @ObservationIgnored
    private var timer: Timer?

    func toggleRun() {
        if isRunning { pause() } else { start() }
    }

    func start() {
        guard !isRunning, !isExpired else { return }
        isRunning = true
        scheduleTimer()
    }

    func pause() {
        isRunning = false
        invalidateTimer()
    }

    /// 初期状態 (30 分) に戻す。onExpiry は呼ばない (手動 reset のため)。
    func reset() {
        invalidateTimer()
        totalSeconds = Self.defaultDurationSeconds
        remainingSeconds = totalSeconds
        isRunning = false
        isExpired = false
    }

    /// 編集確定時: 計測基準値と残り時間を同時に更新し、進捗ゲージをリセットする。
    func setDuration(_ seconds: Int) {
        let clamped = max(0, seconds)
        totalSeconds = clamped
        remainingSeconds = clamped
        isExpired = false
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

    private func tick() {
        guard isRunning, !isEditing else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }
        if remainingSeconds == 0 {
            expire()
        }
    }

    private func expire() {
        isRunning = false
        isExpired = true
        invalidateTimer()
        onExpiry?()
    }
}
