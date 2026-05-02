//
//  TimerView.swift
//  Aidea
//

import SwiftUI

/// ポモドーロタイマーの UI (ヘッダ常駐のインライン表示)。
/// `WidgetView` の子として `AppHeaderView` 右端に常駐する。
/// 上段にアイコン / 残り時間 / 再生・停止 / リセットを横並びで配置し、
/// 下段に上段の幅いっぱいの進捗ゲージを置く 2 段構成。
/// docs/specs/widgets/pomodoro.md 参照。
struct TimerView: View {
    @Environment(PomodoroState.self) private var pomodoro

    @State private var editText: String = ""
    @FocusState private var isTimeFieldFocused: Bool

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                phaseIcon
                timeField
                playPauseButton
                resetButton
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(iconColor)
        }
        .frame(width: 146)
        .help("ポモドーロタイマー (\(pomodoro.phase.label))")
        .onAppear {
            editText = formatRemaining(pomodoro.remainingSeconds)
        }
    }

    /// フェーズに応じたアイコン色 (集中=赤、休憩=緑)
    private var iconColor: Color {
        switch pomodoro.phase {
        case .focus: return .red
        case .rest: return .green
        }
    }

    /// 現在フェーズを示すタイマーアイコン
    private var phaseIcon: some View {
        Image(systemName: "timer")
            .font(.system(size: 18))
            .foregroundStyle(iconColor)
            .frame(width: 24, height: 24)
    }

    /// 開始 / 一時停止トグルボタン
    private var playPauseButton: some View {
        Button {
            pomodoro.toggleRun()
        } label: {
            Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(pomodoro.isRunning ? "一時停止 (⌘⌥P)" : "開始 (⌘⌥P)")
    }

    /// リセットボタン
    private var resetButton: some View {
        Button {
            pomodoro.reset()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("リセット (⌘⌥⇧P)")
    }

    /// 残り時間表示 (編集可能テキストフィールド)
    private var timeField: some View {
        TextField("", text: $editText)
            .focused($isTimeFieldFocused)
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .frame(width: 56)
            .multilineTextAlignment(.center)
            .onSubmit { commitEdit() }
            .onChange(of: isTimeFieldFocused) { _, focused in
                if focused {
                    editText = formatRemaining(pomodoro.remainingSeconds)
                    pomodoro.isEditing = true
                    pomodoro.pause()
                } else {
                    commitEdit()
                }
            }
            .onChange(of: pomodoro.remainingSeconds) { _, newValue in
                if !isTimeFieldFocused {
                    editText = formatRemaining(newValue)
                }
            }
    }

    /// 進捗ゲージ値 (経過率 0.0..1.0)
    private var progress: Double {
        let total = Double(pomodoro.phase.initialSeconds)
        guard total > 0 else { return 0 }
        let elapsed = total - Double(pomodoro.remainingSeconds)
        return min(max(elapsed / total, 0), 1)
    }

    /// 残り時間を `MM:SS` 形式に整形する
    private func formatRemaining(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// 編集確定: `MM:SS` または整数 (分) を受け付ける。不正値は無視して編集モードを抜ける。
    private func commitEdit() {
        defer { pomodoro.isEditing = false }
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        guard let parsed = parseTimeInput(trimmed) else {
            editText = formatRemaining(pomodoro.remainingSeconds)
            return
        }
        pomodoro.setRemainingSeconds(parsed)
        editText = formatRemaining(pomodoro.remainingSeconds)
    }

    /// `MM:SS` または整数 (分) を秒数に変換する
    private func parseTimeInput(_ input: String) -> Int? {
        if input.contains(":") {
            let parts = input.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let m = Int(parts[0]),
                  let s = Int(parts[1]),
                  m >= 0, s >= 0, s < 60 else { return nil }
            return m * 60 + s
        }
        if let m = Int(input), m >= 0 {
            return m * 60
        }
        return nil
    }
}
