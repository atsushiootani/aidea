//
//  DrawioPreview.swift
//  Aidea
//

import SwiftUI
import AppKit

/// drawio ファイル (.drawio.svg / .drawio) を表示する View。
/// 2 つのモードを切り替える:
/// - **view**: 静的な SVG 画像として表示 (`.drawio.svg` は有効な SVG なので NSImage で直接表示可能)
/// - **edit**: DrawioEditor (WKWebView + embed.diagrams.net) で編集
struct DrawioPreview: View {
    let url: URL
    @State private var mode: Mode = .view
    @State private var fileContents: String = ""
    @State private var loadError: String?
    @State private var reloadTick = 0

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
            await loadContents()
        }
    }

    /// モードに応じたメイン表示
    @ViewBuilder
    private var content: some View {
        switch mode {
        case .view:
            // NSImage は SVG の text 要素を描画しきれないので、WebKit で SVG を表示
            DrawioStaticView(url: url, reloadTick: reloadTick)
        case .edit:
            DrawioEditor(
                initialXML: fileContents,
                onSave: { newSVG in
                    save(newSVG: newSVG)
                },
                onCancel: {
                    mode = .view
                }
            )
        }
    }

    /// 右上のフローティングツールバー
    private var toolbar: some View {
        HStack(spacing: 6) {
            if mode == .view {
                Button {
                    mode = .edit
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button {
                    mode = .view
                } label: {
                    Label("キャンセル", systemImage: "xmark")
                        .labelStyle(.titleAndIcon)
                }
                .controlSize(.small)
                Text("保存は drawio 内の 💾 ボタンから")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.regularMaterial)
                    )
            }
        }
        .padding(10)
    }

    /// ファイルを読み込んで fileContents を更新する
    private func loadContents() async {
        do {
            fileContents = try String(contentsOf: url, encoding: .utf8)
            loadError = nil
        } catch {
            loadError = "ファイルを読み込めませんでした: \(error.localizedDescription)"
        }
    }

    /// 新しい SVG を元ファイルに書き戻す
    private func save(newSVG: String) {
        do {
            try newSVG.write(to: url, atomically: true, encoding: .utf8)
            fileContents = newSVG
            reloadTick &+= 1
            mode = .view
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// 中央配置のプレースホルダー
    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
