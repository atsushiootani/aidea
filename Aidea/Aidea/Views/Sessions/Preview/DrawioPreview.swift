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
    /// PreviewSessionState (focusBridge 報告用)
    let state: PreviewSessionState
    @State private var mode: Mode
    @State private var fileContents: String = ""
    @State private var loadError: String?
    @State private var reloadTick = 0
    @State private var convertTick = 0
    @State private var fileWatcher = FileWatcher()
    /// FSEvents で外部変更が検知されるたびにインクリメントされるカウンタ (issue #241)。
    /// view モードのときだけ再読み込みする (edit 中は embed.diagrams.net の未保存状態を壊さない)。
    @State private var fileChangedTick = 0

    enum Mode {
        case view
        case edit
    }

    init(url: URL, state: PreviewSessionState) {
        self.url = url
        self.state = state
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
            fileWatcher.stop()
            // FSEvents はシンボリックリンクを解決した実パスで変更を通知するため、
            // 比較対象も resolvingSymlinksInPath() で揃える (issue #254)
            let watchedURL = url.resolvingSymlinksInPath()
            fileWatcher.start(path: watchedURL.deletingLastPathComponent().path) { paths in
                if paths.contains(watchedURL.path) {
                    fileChangedTick += 1
                }
            }
            await loadContents()
        }
        .onChange(of: fileChangedTick) { _, _ in
            // 外部変更の自動リロード (issue #241)。edit 中は触らない。
            Task { @MainActor in
                guard mode == .view else { return }
                await reloadFromDisk()
            }
        }
        .onChange(of: state.reloadToken) { _, _ in
            // 右クリックメニューの「リロード」(issue #241)。edit 中は編集破棄を避けてスキップ。
            Task { @MainActor in
                guard mode == .view else { return }
                await reloadFromDisk()
            }
        }
    }

    /// ディスクから再読み込みして view 表示を更新する。
    private func reloadFromDisk() async {
        await loadContents()
        reloadTick &+= 1
    }

    /// モードに応じたメイン表示
    @ViewBuilder
    private var content: some View {
        switch mode {
        case .view:
            DrawioStaticView(
                url: url,
                reloadTick: reloadTick,
                convertTick: convertTick,
                onConvert: { svg in
                    convertedSVG(svg)
                },
                onViewCreated: { view in
                    state.focusBridge.setView(view)
                }
            )
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

    /// 右上のフローティングツールバー (view モード時のみ表示)
    @ViewBuilder
    private var toolbar: some View {
        if mode == .view {
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    mode = .edit
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                // .drawio (純 XML) のときのみ "SVG に変換して保存" ボタンを表示
                if !isSVGFormat {
                    Button {
                        convertTick &+= 1
                    } label: {
                        Label("SVG に変換して保存", systemImage: "square.and.arrow.down")
                            .labelStyle(.titleAndIcon)
                    }
                    .controlSize(.small)
                }
            }
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

    /// drawio から xmlsvg export を受け取ったときの処理。
    /// 元ファイル名の末尾に `.svg` を付けて同じディレクトリに書き出す。
    /// 同名ファイルが既にある場合は上書き確認ダイアログを表示する。
    private func convertedSVG(_ svg: String) {
        let destURL = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".svg")

        if FileManager.default.fileExists(atPath: destURL.path) {
            let confirm = NSAlert()
            confirm.messageText = "\(destURL.lastPathComponent) は既に存在します"
            confirm.informativeText = "上書きしますか？"
            confirm.alertStyle = .warning
            confirm.addButton(withTitle: "上書き")
            let cancel = confirm.addButton(withTitle: "キャンセル")
            cancel.keyEquivalent = "\u{1b}" // Esc でキャンセル
            guard confirm.runModal() == .alertFirstButtonReturn else { return }
        }

        do {
            try svg.write(to: destURL, atomically: true, encoding: .utf8)
            let done = NSAlert()
            done.messageText = "SVG として保存しました"
            done.informativeText = destURL.lastPathComponent
            done.alertStyle = .informational
            done.addButton(withTitle: "OK")
            done.runModal()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
