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
    /// PreviewSessionState (focusBridge 報告用)
    let state: PreviewSessionState
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
    @State private var translatedChars: Int = 0
    @State private var translationSiblingOpened: Bool = false
    @State private var isEnglish: Bool = false
    @State private var hasCachedTranslation: Bool = false
    @State private var fileWatcher = FileWatcher()
    /// FSEvents で外部変更が検知されるたびにインクリメントされるカウンタ。
    /// .onChange でトリガーし、view モードのときだけ再読み込みする。
    @State private var fileChangedTick: Int = 0
    /// view モード (純 SwiftUI MarkdownPreview) がアクティブなときに SwiftUI から firstResponder を取るためのフラグ。
    /// state.isActive と onChange で同期する。
    @FocusState private var isFocused: Bool
    /// 上下キー / PageUp / PageDown でのスクロール制御用ブリッジ。
    /// MarkdownPreview に渡すと、内部の NSScrollView を直接操作してスクロールできる。
    @State private var scrollController = ScrollController()

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
            fileWatcher.stop()
            // FSEvents はシンボリックリンクを解決した実パスで変更を通知するため、
            // 比較対象も resolvingSymlinksInPath() で揃える (issue #254)
            let watchedURL = url.resolvingSymlinksInPath()
            fileWatcher.start(path: watchedURL.deletingLastPathComponent().path) { paths in
                if paths.contains(watchedURL.path) {
                    fileChangedTick += 1
                }
            }
            await reload()
        }
        .onChange(of: fileChangedTick) { _, _ in
            // guard は Task 内で再確認する: Task 生成前に guard が通っても、
            // 実行タイミングまでにユーザーが edit モードへ切替えた場合に
            // draftText を上書きしてしまう競合を防ぐ。
            Task { @MainActor in
                guard mode == .view else { return }
                await reload()
            }
        }
        .onChange(of: state.reloadToken) { _, _ in
            // 右クリックメニューの「リロード」(issue #241)。edit 中は編集破棄を避けてスキップ。
            Task { @MainActor in
                guard mode == .view else { return }
                await reload()
            }
        }
        // Session アクティブ状態を SwiftUI の @FocusState に同期する (view モード用)。
        // Kit と同じく「active のときだけ true を立てる」片方向同期にする (false 代入は SwiftUI に任せる)。
        // edit モードでは EditableTextView が NSViewRepresentable として focusBridge 経由で firstResponder を取るため、
        // 本フラグは no-op になる。
        .onChange(of: state.isActive) { _, active in
            if active { isFocused = true }
        }
        .onAppear {
            if state.isActive { isFocused = true }
        }
        // Picker / E キー / toggleMode() いずれの経由でも mode 変更に伴う副作用を 1 箇所で処理する。
        // view → edit: draftText を現在の loadedText で初期化。
        // edit → view: 保留中の自動保存をキャンセルし、差分があれば即座に flush する。
        .onChange(of: mode) { oldValue, newValue in
            switch (oldValue, newValue) {
            case (.view, .edit):
                draftText = loadedText
            case (.edit, .view):
                autoSaveTask?.cancel()
                flushSave()
            default:
                break
            }
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
                // 純 SwiftUI の MarkdownPreview。@FocusState で firstResponder を取り、
                // テキスト選択 (Cmd+C 等) は SwiftUI の標準機構に委譲する。
                // .focusable() で明示的にフォーカス対象化、.focusEffectDisabled() で青枠抑制。
                // scrollController を渡すことで上下 / PageUp / PageDown キーからスクロール可能に。
                MarkdownPreview(
                    text: loadedText,
                    baseURL: url.deletingLastPathComponent(),
                    onLinkTap: onLinkTap,
                    onRunScript: { [registry] command in
                        registry.openTerminalAndRun(command)
                    },
                    tocTopInset: toolbarHeight,
                    scrollController: scrollController
                )
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                // 上下キー: 行単位スクロール (40pt)
                .onKeyPress(.upArrow) {
                    scrollController.scrollBy(-40)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    scrollController.scrollBy(40)
                    return .handled
                }
                // PageUp / PageDown: ページ単位スクロール (viewport 高さの 90%)
                .onKeyPress(.pageUp) {
                    scrollController.pageUp()
                    return .handled
                }
                .onKeyPress(.pageDown) {
                    scrollController.pageDown()
                    return .handled
                }
                // Emacs 風 + コマンド系キー。keys: Set<KeyEquivalent> の overload を使うと
                // クロージャに KeyPress が渡され modifiers を判定できる。
                .onKeyPress(keys: ["p"]) { press in
                    guard isCtrlOnly(press.modifiers) else { return .ignored }
                    scrollController.scrollBy(-40)
                    return .handled
                }
                .onKeyPress(keys: ["n"]) { press in
                    guard isCtrlOnly(press.modifiers) else { return .ignored }
                    scrollController.scrollBy(40)
                    return .handled
                }
                .onKeyPress(keys: ["v"]) { press in
                    guard isCtrlOnly(press.modifiers) else { return .ignored }
                    scrollController.pageDown()
                    return .handled
                }
                .onKeyPress(keys: ["z"]) { press in
                    guard isCtrlOnly(press.modifiers) else { return .ignored }
                    scrollController.pageUp()
                    return .handled
                }
                // E: Edit モードへ切替 (キャッシュファイル = 翻訳済は edit 対象外なので弾く)
                .onKeyPress(keys: ["e"]) { press in
                    guard press.modifiers.isEmpty, !isCachedFile else { return .ignored }
                    toggleMode()
                    return .handled
                }
                // J: 日本語翻訳 (フローティング翻訳ボタンの表示条件と同じ: isEnglish && !isCachedFile)
                .onKeyPress(keys: ["j"]) { press in
                    guard press.modifiers.isEmpty, isEnglish, !isCachedFile else { return .ignored }
                    translateDocument()
                    return .handled
                }
                // Tab: SwiftUI の標準 focus nav を止める (Git/GitDiff 等へのフォーカス漏れ防止)
                .onKeyPress(.tab) { .handled }
            }
        case .edit:
            // NSTextView ベース: focusBridge 経由で firstResponder を取る (AppKit 経路)
            EditableTextView(text: $draftText, onViewCreated: { view in
                state.focusBridge.setView(view)
            })
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
                // view / edit のセグメントコントロール (アイコンのみ)。
                // mode 変更の副作用 (draft 初期化 / 保存 flush) は .onChange(of: mode) 側で処理する。
                Picker("", selection: $mode) {
                    Image(systemName: "eye").tag(Mode.view)
                    Image(systemName: "chevron.left.forwardslash.chevron.right").tag(Mode.edit)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }

            // 英語ドキュメントの場合に翻訳ボタンを表示 (キャッシュファイルでは非表示)
            if mode == .view && isEnglish && !isCachedFile {
                Button {
                    translateDocument()
                } label: {
                    if isTranslating {
                        if translatedChars > 0 {
                            Label("翻訳中... (\(translatedChars)文字)", systemImage: "hourglass")
                                .labelStyle(.titleAndIcon)
                        } else {
                            Label("翻訳中...", systemImage: "hourglass")
                                .labelStyle(.titleAndIcon)
                        }
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

    /// Control キーだけが押されている状態か (他の modifier は含まない) を判定する。
    /// Emacs 風 Ctrl+N/P/V/Z のキー処理で使う。
    private func isCtrlOnly(_ modifiers: EventModifiers) -> Bool {
        modifiers == [.control]
    }

    /// view ⇄ edit のトグル。E キーから呼ばれる。
    /// 副作用 (draft 初期化・保存 flush) は mode の .onChange で処理されるため、ここでは値の反転のみ行う。
    private func toggleMode() {
        mode = (mode == .view) ? .edit : .view
    }

    /// ファイルを読み込み、英語判定を行う
    private func reload() async {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            loadedText = content
            // edit モード中は draftText を上書きしない: ユーザーが入力中の変更を保護する。
            // fileChangedTick 経由の呼び出しは Task 内でも mode チェック済みだが、
            // task(id: url) 経由 (URL 変更時) でも edit モード中に呼ばれる場合を考慮する。
            if mode == .view {
                draftText = content
            }
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

    /// Claude API で SSE ストリーミング翻訳して隣タブに開く
    private func translateDocument() {
        guard let projectRoot = workspace.projectRoot else { return }
        guard let cachedURL = TranslationCache.cachedURL(for: url, projectRoot: projectRoot) else { return }

        isTranslating = true
        translatedChars = 0
        translationSiblingOpened = false

        let fileName = url.deletingPathExtension().lastPathComponent

        Task {
            do {
                try await TranslationService.translateIfNeeded(
                    originalURL: url,
                    projectRoot: projectRoot,
                    onProgress: { @MainActor chars in
                        translatedChars = chars
                        // 最初のチャンク受信時に sibling タブを開く (FileWatcher が以降の更新を反映)
                        if chars > 0, !translationSiblingOpened {
                            translationSiblingOpened = true
                            registry.openPreviewAsSibling(for: cachedURL, title: "\(fileName) (日本語)")
                        }
                    }
                )
                isTranslating = false
                translatedChars = 0
                hasCachedTranslation = true
                // キャッシュが新鮮だった場合 (onProgress 未呼び出し) はここでタブを開く
                if !translationSiblingOpened {
                    registry.openPreviewAsSibling(for: cachedURL, title: "\(fileName) (日本語)")
                }
                translationSiblingOpened = false
            } catch {
                isTranslating = false
                translatedChars = 0
                translationSiblingOpened = false
                NSAlert(error: error).runModal()
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
