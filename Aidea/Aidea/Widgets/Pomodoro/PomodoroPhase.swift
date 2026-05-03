//
//  PomodoroPhase.swift
//  Aidea
//

import Foundation

/// ポモドーロタイマーのフェーズ。集中 (focus) と休憩 (rest) を交互に切り替える。
/// docs/specs/widgets/pomodoro.md 参照。
enum PomodoroPhase {
    case focus
    case rest

    /// このフェーズの初期残り秒数 (集中: 1500s = 25 分、休憩: 300s = 5 分)
    var initialSeconds: Int {
        switch self {
        case .focus: return 1500
        case .rest: return 300
        }
    }

    /// 自動遷移で次に進むフェーズ (focus → rest → focus → ...)
    var next: PomodoroPhase {
        switch self {
        case .focus: return .rest
        case .rest: return .focus
        }
    }

    /// UI ラベル
    var label: String {
        switch self {
        case .focus: return "集中中"
        case .rest: return "休憩中"
        }
    }
}
