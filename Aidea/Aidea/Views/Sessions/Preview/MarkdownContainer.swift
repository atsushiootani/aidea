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

    @Environment(WorkspaceState.self) private var workspace
    @Environment(SessionRegistry.self) private var registry
    @State private var mode: Mode = .view
    @State private var loadedText: String = ""
    @State private var draftText: String = ""
    @State private var loadError: String?
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var isTranslating: Bool = false
    @State private var isEnglish: Bool = false
    @State private var hasCachedTranslation: Bool = false

    /// このファイルが .aidea/ja/ 配下の翻訳キャッシュかどうか
    private var isCachedFile: Bool { TranslationCache.isCachedFile(url) }

    /// 右上ボタンの領域に ToC が重ならないよう、ToC を下に押し下げる量
    private let toolbarHeight: CGFloat = 80

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

    /// 右上のフローティングツールバー
    @ViewBuilder
    private var toolbar: some View {
        VStack(alignment: .trailing, spacing: 6) {
            // .aidea/ja/ のキャッシュファイルなら Edit ではなく「英語」ボタンを表示
            if isCachedFile {
                if mode == .view {
                    Button {
                        openOriginalFile()
                    } label: {
                        Label("英語", systemImage: "character.book.closed")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                Button {
                    toggleMode()
                } label: {
                    Label(mode == .view ? "Edit" : "View",
                          systemImage: mode == .view ? "pencil" : "eye")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            // 英語ドキュメントの場合に翻訳ボタンを表示 (キャッシュファイルでは非表示)
            if mode == .view && isEnglish && !isCachedFile {
                Button {
                    translateDocument()
                } label: {
                    if isTranslating {
                        Label("翻訳中...", systemImage: "hourglass")
                            .labelStyle(.titleAndIcon)
                    } else {
                        Label("日本語", systemImage: hasCachedTranslation
                              ? "character.book.closed.ja.fill"
                              : "character.book.closed.ja")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .controlSize(.small)
                .disabled(isTranslating)
            }
        }
        .padding(.top, 10)
        .padding(.trailing, 22)
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

    /// ファイルを読み込み、英語判定を行う
    private func reload() async {
        do {
            loadedText = try String(contentsOf: url, encoding: .utf8)
            draftText = loadedText
            loadError = nil
            isEnglish = LanguageDetector.isEnglish(loadedText)
            if isEnglish, let projectRoot = workspace.projectRoot {
                hasCachedTranslation = checkCache(projectRoot: projectRoot)
            } else {
                hasCachedTranslation = false
            }
        } catch {
            loadError = "ファイルを読み込めませんでした: \(error.localizedDescription)"
            isEnglish = false
            hasCachedTranslation = false
        }
    }

    /// 元の英語ファイルを隣タブで開く (.aidea/ja/ → 元ファイル)
    private func openOriginalFile() {
        guard let projectRoot = workspace.projectRoot,
              let originalURL = TranslationCache.originalURL(for: url, projectRoot: projectRoot) else { return }
        let fileName = originalURL.deletingPathExtension().lastPathComponent
        registry.openPreviewAsSibling(for: originalURL, title: fileName)
    }

    /// キャッシュが存在し鮮度があるか確認する
    private func checkCache(projectRoot: URL) -> Bool {
        guard let cached = TranslationCache.cachedURL(for: url, projectRoot: projectRoot) else { return false }
        return TranslationCache.isFresh(original: url, cached: cached)
    }

    /// Claude API で翻訳して隣タブに開く
    private func translateDocument() {
        guard let projectRoot = workspace.projectRoot else { return }
        isTranslating = true
        Task {
            do {
                let cachedURL = try await TranslationService.translateIfNeeded(
                    originalURL: url,
                    projectRoot: projectRoot
                )
                await MainActor.run {
                    isTranslating = false
                    let fileName = url.deletingPathExtension().lastPathComponent
                    registry.openPreviewAsSibling(
                        for: cachedURL,
                        title: "\(fileName) (日本語)"
                    )
                }
            } catch {
                await MainActor.run {
                    isTranslating = false
                    NSAlert(error: error).runModal()
                }
            }
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
