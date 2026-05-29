//
//  QuickMemoState.swift
//  Aidea
//

import Foundation
import Observation

/// クイックメモの状態管理。
/// isPresented で popover の開閉を制御し、open 時に memo.md を読み込み、save 時に上書きする。
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

    /// popover オープン時に <projectRoot>/.aidea/widgets/quickmemo/memo.md を読み込む。
    /// ファイルが無い・読み込み失敗時は空欄から始める。
    func load(projectRoot: URL) {
        let file = Self.memoFileURL(projectRoot: projectRoot)
        if let text = try? String(contentsOf: file, encoding: .utf8) {
            memoText = text
        } else {
            memoText = ""
        }
    }

    /// メモを <projectRoot>/.aidea/widgets/quickmemo/memo.md に上書き保存して popover を閉じる。
    /// 保存失敗時は popover を閉じない。
    func save(projectRoot: URL) {
        let trimmed = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let file = Self.memoFileURL(projectRoot: projectRoot)
        let dir = file.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try memoText.write(to: file, atomically: true, encoding: .utf8)
            isPresented = false
            memoText = ""
        } catch {
            NSLog("[QuickMemo] 保存失敗: \(error)")
        }
    }

    private static func memoFileURL(projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent(".aidea/widgets/quickmemo", isDirectory: true)
            .appendingPathComponent("memo.md")
    }
}
