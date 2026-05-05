//
//  SpeechHistoryView.swift
//  Aidea
//

import SwiftUI

/// Companion ごとの speech ファイル履歴を一覧表示する sheet。
/// `.aidea/backchannels/<companionIndex>/speech-*.txt` をタイムスタンプ降順で表示する。
struct SpeechHistoryView: View {
    let companionIndex: Int
    let projectRoot: URL?

    @State private var entries: [SpeechEntry] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("speech 履歴")
                    .font(.headline)
                Spacer()
                Button("閉じる") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if entries.isEmpty {
                Spacer()
                Text("履歴がありません")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.formattedTimestamp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.text)
                            .font(.body)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 480, height: 400)
        .onAppear { entries = loadEntries() }
    }

    private func loadEntries() -> [SpeechEntry] {
        guard let root = projectRoot else { return [] }
        let dir = root.appending(path: ".aidea/backchannels/\(companionIndex)")
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }

        return urls
            .filter { $0.lastPathComponent.hasPrefix("speech-") && $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .compactMap { url -> SpeechEntry? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let parsed = SpeechWatcher.parse(content)
                guard !parsed.text.isEmpty else { return nil }
                return SpeechEntry(filename: url.lastPathComponent, text: parsed.text)
            }
    }
}

private struct SpeechEntry: Identifiable {
    let id = UUID()
    let filename: String
    let text: String

    /// `speech-YYYYMMDDTHHmmss.txt` → `YYYY/MM/DD HH:mm:ss`
    var formattedTimestamp: String {
        let stem = filename
            .replacingOccurrences(of: "speech-", with: "")
            .replacingOccurrences(of: ".txt", with: "")
        // Expected: 20260423T164822
        guard stem.count == 15,
              let tIdx = stem.firstIndex(of: "T") else { return stem }
        let datePart = stem[stem.startIndex..<tIdx]
        let timePart = stem[stem.index(after: tIdx)...]
        guard datePart.count == 8, timePart.count == 6 else { return stem }
        let y = datePart.prefix(4)
        let mo = datePart.dropFirst(4).prefix(2)
        let d = datePart.dropFirst(6).prefix(2)
        let h = timePart.prefix(2)
        let mi = timePart.dropFirst(2).prefix(2)
        let s = timePart.dropFirst(4).prefix(2)
        return "\(y)/\(mo)/\(d) \(h):\(mi):\(s)"
    }
}
