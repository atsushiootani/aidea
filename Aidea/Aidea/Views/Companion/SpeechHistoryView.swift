//
//  SpeechHistoryView.swift
//  Aidea
//

import SwiftUI

/// Companion が書き出した speech ファイルを逆時系列で表示する読み取り専用ビュー。
/// `CompanionEditView` の「speech 履歴」ボタンから sheet として開かれる。
struct SpeechHistoryView: View {
    let companionIndex: Int
    let projectRoot: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [(filename: String, text: String)] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 500, height: 420)
        .onAppear { loadEntries() }
    }

    private var header: some View {
        HStack {
            Text("Speech 履歴")
                .font(.headline)
            Spacer()
            Button("閉じる") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            Text("履歴がありません")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(entries, id: \.filename) { entry in
                        entryRow(entry)
                    }
                }
                .padding()
            }
        }
    }

    private func entryRow(_ entry: (filename: String, text: String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.filename)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontDesign(.monospaced)
            Text(entry.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func loadEntries() {
        guard let projectRoot else { return }
        let dir = projectRoot.appending(path: ".aidea/backchannels/\(companionIndex)")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else { return }

        entries = files
            .filter { $0.lastPathComponent.hasPrefix("speech-") && $0.pathExtension == "txt" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .compactMap { url -> (filename: String, text: String)? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let parsed = SpeechWatcher.parse(content)
                guard !parsed.text.isEmpty else { return nil }
                return (filename: url.lastPathComponent, text: parsed.text)
            }
    }
}
