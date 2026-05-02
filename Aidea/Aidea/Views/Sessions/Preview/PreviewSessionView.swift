//
//  PreviewSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// Preview Session の SwiftUI View。state.url のファイルを表示する。
struct PreviewSessionView: View {
    let state: PreviewSessionState
    let sessionID: SessionID
    @Environment(SessionRegistry.self) private var registry
    @Environment(WorkspaceState.self) private var workspace
    @State private var preview: PreviewContent = .empty
    @State private var loadedURL: URL?
    @State private var isEnglishText: Bool = false
    @State private var isTranslating: Bool = false
    @State private var hasCachedTranslation: Bool = false

    nonisolated private static let maxFileSize: Int = 1_000_000
    nonisolated private static let binarySniffSize: Int = 8192

    var body: some View {
        Group {
            if let url = state.url, isDrawioURL(url) {
                DrawioPreview(url: url, state: state)
            } else if let url = state.url, isMarkdownURL(url) {
                MarkdownContainer(
                    url: url,
                    state: state,
                    onLinkTap: { resolvedURL in
                        registry.openPreviewAsSibling(
                            for: resolvedURL,
                            title: resolvedURL.lastPathComponent
                        )
                    }
                )
            } else {
                switch preview {
                case .empty:
                    placeholder("ファイルが選択されていません\n(ファイラでファイルをクリックすると表示されます)")
                case .loading:
                    placeholder("読み込み中...")
                case .text(let content):
                    ZStack(alignment: .topTrailing) {
                        NSTextPreview(text: content, onViewCreated: { view in
                            state.focusBridge.setView(view)
                        })
                        if isEnglishText {
                            translateButton
                                .padding(.top, 10)
                                .padding(.trailing, 22)
                        }
                    }
                case .image(let image):
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                case .message(let text):
                    placeholder(text)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: state.url) {
            // URL 変更時は bridge をクリアしない: 子ビュー (NSTextPreview 等) の makeNSView が
            // body 評価中に既に setView を済ませている可能性があるため、ここで nil 代入すると
            // 登録直後の値が消える。古いコンテンツの NSView は dismantle 時に bridge の
            // weak ref が自動で nil になる。
            // 純 SwiftUI コンテンツ (markdown view / image) は @FocusState + state.isActive で
            // 独立にフォーカスを取るため、bridge の状態は影響しない。
            isEnglishText = false
            await loadPreview(for: state.url)
            // テキストの場合は英語判定 + キャッシュ確認
            if case .text(let content) = preview {
                isEnglishText = LanguageDetector.isEnglish(content)
                if isEnglishText, let url = state.url, let root = workspace.projectRoot,
                   let cached = TranslationCache.cachedURL(for: url, projectRoot: root) {
                    hasCachedTranslation = TranslationCache.isFresh(original: url, cached: cached)
                } else {
                    hasCachedTranslation = false
                }
            }
            // コンテンツロード後にリフォーカス (bridge の pending が解消される)
            if registry.activeSessionID == sessionID {
                registry.reactivateCurrentSession()
            }
        }
    }

    /// 翻訳ボタン (テキスト全般用)
    private var translateButton: some View {
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

    /// Claude API で翻訳して隣タブに開く
    private func translateDocument() {
        guard let url = state.url, let projectRoot = workspace.projectRoot else { return }
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

    /// 拡張子から drawio ファイルか判定する (.drawio.svg / .drawio)
    private func isDrawioURL(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name.hasSuffix(".drawio.svg") || name.hasSuffix(".drawio")
    }

    /// プレースホルダー文言
    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    /// 非同期でファイルを読み込んで preview を更新する
    private func loadPreview(for url: URL?) async {
        guard let url = url else {
            preview = .empty
            loadedURL = nil
            return
        }
        if loadedURL == url, case .text = preview { return }
        preview = .loading
        loadedURL = url

        let result = await Task.detached(priority: .userInitiated) { () -> PreviewContent in
            let ext = url.pathExtension.lowercased()
            let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "webp", "bmp"]
            if imageExts.contains(ext) {
                if let image = NSImage(contentsOf: url) {
                    return .image(image)
                }
                return .message("画像を読み込めませんでした")
            }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int, size > Self.maxFileSize {
                return .message("ファイルが大きすぎます (\(size / 1024) KB)")
            }
            if Self.isBinary(url: url) {
                return .message("プレビュー非対応のバイナリです")
            }
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return .text(text)
            }
            return .message("ファイルを読み込めませんでした")
        }.value

        if loadedURL == url {
            preview = result
        }
    }

    /// 拡張子から Markdown ファイルか判定する
    private func isMarkdownURL(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }

    /// 先頭 8KB に NUL バイトが含まれていればバイナリとみなす
    nonisolated private static func isBinary(url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return true }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: binarySniffSize)) ?? Data()
        return data.contains(0)
    }
}

/// プレビュー結果の状態
enum PreviewContent {
    case empty
    case loading
    case text(String)
    case image(NSImage)
    case message(String)
}

/// NSTextView を NSViewRepresentable でラップして大きなテキストでも高速にスクロールできるようにする。
struct NSTextPreview: NSViewRepresentable {
    let text: String
    /// NSTextView が生成されたときに呼ばれるコールバック (SessionFocusBridge 報告用)
    var onViewCreated: ((NSView) -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = text
        onViewCreated?(textView)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
}
