//
//  QuickMemoState.swift
//  Aidea
//

import Foundation
import Observation

/// クイックメモの状態。Cmd+M で開くメモパネルの入力テキストと表示状態を管理する。
/// 保存先: <projectRoot>/quickmemo/todo/<timestamp>.md
/// docs/specs/widgets/quick-memo.md 参照。
@MainActor
@Observable
final class QuickMemoState {
    var isPresented: Bool = false
    var draftText: String = ""

    func present() {
        draftText = ""
        isPresented = true
    }

    func save(to projectRoot: URL) {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dismiss()
            return
        }
        let dir = projectRoot.appendingPathComponent("quickmemo/todo")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(Self.fileTimestamp()).md")
        try? trimmed.write(to: file, atomically: true, encoding: .utf8)
        dismiss()
    }

    func dismiss() {
        isPresented = false
        draftText = ""
    }

    private static func fileTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
