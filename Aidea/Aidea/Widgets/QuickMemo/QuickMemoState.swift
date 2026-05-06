//
//  QuickMemoState.swift
//  Aidea
//

import Foundation
import Observation

/// クイックメモの状態管理。
/// isPresented で popover の開閉を制御し、保存時に quickmemo/todo/ へファイルを書き出す。
/// docs/specs/widgets/quick-memo.md 参照。
@MainActor
@Observable
final class QuickMemoState {
    var isPresented: Bool = false
    var memoText: String = ""

    func togglePresented() {
        isPresented.toggle()
        if !isPresented {
            memoText = ""
        }
    }

    func open() {
        isPresented = true
    }

    func cancel() {
        isPresented = false
        memoText = ""
    }

    /// メモを <projectRoot>/quickmemo/todo/<timestamp>.md に保存して popover を閉じる。
    /// 保存失敗時は popover を閉じない。
    func save(projectRoot: URL) {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let dir = projectRoot.appendingPathComponent("quickmemo/todo", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let timestamp = Self.timestampString()
            let file = dir.appendingPathComponent("\(timestamp).md")
            try memoText.write(to: file, atomically: true, encoding: .utf8)
            isPresented = false
            memoText = ""
        } catch {
            NSLog("[QuickMemo] 保存失敗: \(error)")
        }
    }

    private static func timestampString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HHmmss"
        return fmt.string(from: Date())
    }
}
