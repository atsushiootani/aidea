//
//  MarkdownContainer.swift
//  Aidea
//

import SwiftUI
import AppKit

/// Markdown ファイルをプレビュー/編集する View。
/// drawio の DrawioPreview と同じく view/edit モードを切り替える構造。
/// edit モードでは入力を 500ms デバウンスして自動保存する。
struct MarkdownContainer: View {
    let url: URL
    /// Session (focusableView 報告用)
    let session: Session
    /// Markdown 内のファイルリンクがタップされたときに呼ばれる
    let onLinkTap: ((URL) -> Void)?

    @State private var mode: Mode = .view
    @State private var loadedText: String = ""
    @State private var draftText: String = ""
    @State private var loadError: String?
    /// 自動保存デバウンス用のタスク
    @State private var autoSaveTask: Task<Void, Never>?

    /// 右上ボタンの領域に ToC が重ならないよう、ToC を下に押し下げる量
    private let toolbarHeight: CGFloat = 44

    enum Mode {
        case view
        case edit
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            toolbar
        }
        .task(id: url) {
            await reload()
        }
    }

    /// モードに応じたメイン表示
    @ViewBuilder
    private var content: some View {
        switch mode {
        case .view:
            if let error = loadError {
                placeholder(error)
            } else {
                MarkdownPreview(
                    text: loadedText,
                    baseURL: url.deletingLastPathComponent(),
                    onLinkTap: onLinkTap,
                    tocTopInset: toolbarHeight
                )
                .background(FocusCatcherView(onViewCreated: { session.focusableView = $0 }))
            }
        case .edit:
            EditableTextView(text: $draftText, onViewCreated: { self.session.focusableView = $0 })
                .onChange(of: draftText) { _, newValue in
                    scheduleAutoSave(newValue)
                }
        }
    }

    /// 右上のフローティングツールバー (view モード: Edit / edit モード: View)
    @ViewBuilder
    private var toolbar: some View {
        Button {
            toggleMode()
        } label: {
            Label(mode == .view ? "Edit" : "View",
                  systemImage: mode == .view ? "pencil" : "eye")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .padding(.top, 10)
        .padding(.trailing, 22) // スクロールバーと重ならないように余裕を持たせる
    }

    /// view ⇄ edit のトグル
    private func toggleMode() {
        switch mode {
        case .view:
            draftText = loadedText
            mode = .edit
        case .edit:
            // 切替前に保留の自動保存があれば即座にフラッシュする
            autoSaveTask?.cancel()
            flushSave()
            mode = .view
        }
    }

    /// ファイルを読み込む
    private func reload() async {
        do {
            loadedText = try String(contentsOf: url, encoding: .utf8)
            draftText = loadedText
            loadError = nil
        } catch {
            loadError = "ファイルを読み込めませんでした: \(error.localizedDescription)"
        }
    }

    /// 編集中の自動保存をデバウンス付きでスケジュールする
    private func scheduleAutoSave(_ newValue: String) {
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            if Task.isCancelled { return }
            flushSave()
        }
    }

    /// 現在の draftText をファイルに書き戻す (差分がなければ何もしない)
    private func flushSave() {
        guard draftText != loadedText else { return }
        do {
            try draftText.write(to: url, atomically: true, encoding: .utf8)
            loadedText = draftText
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// 読み込みエラー等のプレースホルダー表示
    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
