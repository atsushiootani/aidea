//
//  PreviewSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// Preview Session の SwiftUI View。state.url のファイルを表示する。
struct PreviewSessionView: View {
    let session: Session
    let state: PreviewSessionState
    let sessionID: SessionID
    @Environment(SessionRegistry.self) private var registry
    @State private var preview: PreviewContent = .empty
    @State private var loadedURL: URL?

    private static let maxFileSize: Int = 1_000_000
    private static let binarySniffSize: Int = 8192

    var body: some View {
        Group {
            if let url = state.url, isDrawioURL(url) {
                DrawioPreview(url: url, session: session)
            } else if let url = state.url, isMarkdownURL(url) {
                MarkdownContainer(
                    url: url,
                    session: session,
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
                    NSTextPreview(text: content, onViewCreated: { session.focusableView = $0 })
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
            // URL 変更時は focusableView をクリア (子ビューが再設定する)
            session.focusableView = nil
            await loadPreview(for: state.url)
            // コンテンツロード後にリフォーカス
            if registry.activeSessionID == sessionID {
                registry.reactivateCurrentSession()
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
    private static func isBinary(url: URL) -> Bool {
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
    /// NSTextView が生成されたときに呼ばれるコールバック (focusableView 報告用)
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
