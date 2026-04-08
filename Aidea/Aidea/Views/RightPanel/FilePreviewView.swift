//
//  FilePreviewView.swift
//  Aidea
//

import SwiftUI
import AppKit

/// WorkspaceState.selectedFile を監視して、テキスト/画像/非対応 を自動判別して表示する View。
/// 非同期でファイルを読み込み、結果を @State にキャッシュする。
struct FilePreviewView: View {
    @Environment(WorkspaceState.self) private var workspace
    @State private var preview: PreviewContent = .empty
    @State private var loadedURL: URL?

    /// プレビュー対象の最大サイズ (1 MB)
    private static let maxFileSize: Int = 1_000_000

    /// バイナリ判定に使う先頭バイト数
    private static let binarySniffSize: Int = 8192

    var body: some View {
        Group {
            switch preview {
            case .empty:
                placeholder("ファイルが選択されていません")
            case .loading:
                placeholder("読み込み中...")
            case .text(let content):
                NSTextPreview(text: content)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: workspace.selectedFile) {
            await loadPreview(for: workspace.selectedFile)
        }
    }

    /// プレースホルダー文言
    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text).foregroundStyle(.secondary)
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

        // バックグラウンドでファイル判別 + 読み込み
        let result = await Task.detached(priority: .userInitiated) { () -> PreviewContent in
            let ext = url.pathExtension.lowercased()
            let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "webp", "bmp"]
            if imageExts.contains(ext) {
                if let image = NSImage(contentsOf: url) {
                    return .image(image)
                }
                return .message("画像を読み込めませんでした")
            }
            // サイズチェック
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int, size > Self.maxFileSize {
                return .message("ファイルが大きすぎます (\(size / 1024) KB)")
            }
            // バイナリ判定
            if Self.isBinary(url: url) {
                return .message("プレビュー非対応のバイナリです")
            }
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return .text(text)
            }
            return .message("ファイルを読み込めませんでした")
        }.value

        // 選択が変わっていなければ反映
        if loadedURL == url {
            preview = result
        }
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

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = text
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
}
