//
//  FocusTimerView.swift
//  Aidea
//

import SwiftUI

/// 没入防止タイマーの UI (ヘッダ常駐のインライン表示)。
/// `WidgetView` の子として `AppHeaderView` 右端に常駐する。
/// 上段にアイコン / 残り時間 / 再生・停止 / リセットを横並びで配置し、
/// 下段に上段の幅いっぱいの進捗ゲージを置く 2 段構成。
/// docs/specs/widgets/focus-timer.md 参照。
struct FocusTimerView: View {
    @Environment(FocusTimerState.self) private var focusTimer

    @State private var editText: String = ""
    @FocusState private var isTimeFieldFocused: Bool

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                timerIcon
                timeField
                playPauseButton
                resetButton
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(accentColor)
        }
        .frame(width: 146)
        .help(focusTimer.isExpired ? "没入防止タイマー (時間切れ)" : "没入防止タイマー")
        .onAppear {
            editText = formatSeconds(focusTimer.remainingSeconds)
        }
    }

    private var accentColor: Color {
        focusTimer.isExpired ? .orange : .blue
    }

    private var timerIcon: some View {
        Group {
            if focusTimer.isExpired {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.orange)
                    .symbolEffect(.pulse)
            } else {
                Image(systemName: "hourglass")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.blue)
            }
        }
        .frame(width: 24, height: 24)
    }

    private var playPauseButton: some View {
        Button {
            focusTimer.toggleRun()
        } label: {
            Image(systemName: focusTimer.isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(focusTimer.isExpired)
        .help(focusTimer.isRunning ? "一時停止 (⌘⌥F)" : "開始 (⌘⌥F)")
    }

    private var resetButton: some View {
        Button {
            focusTimer.reset()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("リセット (⌘⌥⇧F)")
    }

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
                    editText = formatSeconds(focusTimer.remainingSeconds)
                    focusTimer.isEditing = true
                    focusTimer.pause()
                } else {
                    commitEdit()
                }
            }
            .onChange(of: focusTimer.remainingSeconds) { _, newValue in
                if !isTimeFieldFocused {
                    editText = formatSeconds(newValue)
                }
            }
    }

    private var progress: Double {
        guard focusTimer.totalSeconds > 0 else { return 0 }
        let elapsed = Double(focusTimer.totalSeconds) - Double(focusTimer.remainingSeconds)
        return min(max(elapsed / Double(focusTimer.totalSeconds), 0), 1)
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func commitEdit() {
        defer { focusTimer.isEditing = false }
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        guard let parsed = parseTimeInput(trimmed) else {
            editText = formatSeconds(focusTimer.remainingSeconds)
            return
        }
        focusTimer.setDuration(parsed)
        editText = formatSeconds(focusTimer.remainingSeconds)
    }

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
