//
//  DrawioPreview.swift
//  Aidea
//

import SwiftUI
import AppKit

/// drawio ファイル (.drawio.svg / .drawio) を表示する View。
///
/// ファイル種別ごとの挙動:
/// - **`.drawio.svg`**: 静的 SVG 表示 (view) と drawio エディタ (edit) を切り替え可能。
/// - **`.drawio`**: 静的プレビューの手段がないため、常にエディタで表示する。
struct DrawioPreview: View {
    let url: URL
    @State private var mode: Mode
    @State private var fileContents: String = ""
    @State private var loadError: String?
    @State private var reloadTick = 0

    enum Mode {
        case view
        case edit
    }

    init(url: URL) {
        self.url = url
        // .drawio / .drawio.svg どちらも初期は view モード
        // (.drawio は DrawioStaticView 内で drawio embed の chrome=0 ビューワを使う)
        _mode = State(initialValue: .view)
    }

    /// このファイルが .drawio.svg 形式か (そうでなければ .drawio)
    private var isSVGFormat: Bool {
        url.lastPathComponent.lowercased().hasSuffix(".drawio.svg")
    }

    /// drawio のエクスポート形式
    private var exportFormat: DrawioEditor.ExportFormat {
        isSVGFormat ? .xmlsvg : .xml
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
            DrawioStaticView(url: url, reloadTick: reloadTick)
        case .edit:
            DrawioEditor(
                initialXML: fileContents,
                exportFormat: exportFormat,
                onSave: { newContent in
                    save(newContent: newContent)
                },
                onCancel: {
                    mode = .view
                }
            )
        }
    }

    /// 右上のフローティングツールバー (view モード時のみ Edit ボタン表示)
    @ViewBuilder
    private var toolbar: some View {
        if mode == .view {
            Button {
                mode = .edit
            } label: {
                Label("Edit", systemImage: "pencil")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(10)
        }
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

    /// 新しいコンテンツ (SVG or XML) を元ファイルに書き戻す
    private func save(newContent: String) {
        do {
            try newContent.write(to: url, atomically: true, encoding: .utf8)
            fileContents = newContent
            reloadTick &+= 1
            mode = .view
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
