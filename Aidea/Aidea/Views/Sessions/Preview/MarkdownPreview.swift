//
//  MarkdownPreview.swift
//  Aidea
//

import SwiftUI

/// Markdown テキストを見やすく表示する SwiftUI View。
/// 行ベースのシンプルなパーサで以下をサポート:
/// - `# / ## / ### / ####` 見出し (折りたたみ可)
/// - `` ``` `` フェンス付きコードブロック
/// - `- ` / `* ` 箇条書き
/// - `- [ ]` / `- [x]` チェックボックス (アイコン表示)
/// - `| col | col |` テーブル
/// - 通常段落 (インラインの `**bold**` `*italic*` `[link](url)` `` `code` `` は
///   SwiftUI `Text(.init(String))` のネイティブ Markdown パースに任せる)
/// - YAML frontmatter (`---` で囲まれたブロック) は薄く表示
/// - 右上フローティングの目次 (ToC)、クリックで該当見出しにスクロール
struct MarkdownPreview: View {
    let text: String
    /// 相対リンクを解決するためのベースディレクトリ (通常は元ファイルの親)
    let baseURL: URL?
    /// ローカルファイルへのリンクがクリックされたときに呼ばれる (resolved 絶対 URL)
    let onLinkTap: ((URL) -> Void)?
    /// シェルスクリプトコードブロックの実行ボタンが押されたときに呼ばれる (スクリプト本文)
    let onRunScript: ((String) -> Void)?
    /// 目次 (ToC) の上部に確保する追加のマージン (親側にフローティングボタン等がある場合)
    let tocTopInset: CGFloat
    /// オプション: 親から受け取るスクロールコントローラ。キー操作でスクロールさせるときに使う。
    /// 非 nil の場合は ScrollView 内部に透明 NSView を仕込んで NSScrollView を橋渡しする。
    let scrollController: ScrollController?

    /// 折りたたみ中の見出し行インデックス集合
    @State private var collapsedHeadings: Set<Int> = []
    /// ToC の表示/非表示
    @State private var showTOC: Bool = true

    init(
        text: String,
        baseURL: URL? = nil,
        onLinkTap: ((URL) -> Void)? = nil,
        onRunScript: ((String) -> Void)? = nil,
        tocTopInset: CGFloat = 0,
        scrollController: ScrollController? = nil
    ) {
        self.text = text
        self.baseURL = baseURL
        self.onLinkTap = onLinkTap
        self.onRunScript = onRunScript
        self.tocTopInset = tocTopInset
        self.scrollController = scrollController
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(visibleIndices, id: \.self) { index in
                            render(index: index, line: lines[index])
                                .id("line-\(index)")
                        }
                        // スクロールコントローラの橋渡し用の透明 NSView
                        // (NSScrollView を enclosingScrollView 経由で掴むため content 内に配置する)
                        if let controller = scrollController {
                            ScrollCommanderView(controller: controller)
                                .frame(width: 0, height: 0)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                .environment(\.openURL, OpenURLAction { url in
                    handleLinkTap(url)
                })
                .overlay(alignment: .topTrailing) {
                    tableOfContents(proxy: proxy)
                        .padding(.top, tocTopInset)
                }
            }
        }
    }

    // MARK: - Parsing

    /// テキストを行ベースでパースした結果 (頻繁に呼ばれないよう computed)
    private var lines: [MarkdownLine] {
        Self.parseLines(text)
    }

    /// 折りたたみ考慮後の表示対象インデックス
    private var visibleIndices: [Int] {
        var result: [Int] = []
        var skipUntilLevel: Int? = nil
        for (index, line) in lines.enumerated() {
            // 折りたたみ中のセクションをスキップ
            if let lvl = skipUntilLevel {
                if case .heading(let level, _) = line, level <= lvl {
                    skipUntilLevel = nil
                } else {
                    continue
                }
            }
            result.append(index)
            if case .heading(let level, _) = line, collapsedHeadings.contains(index) {
                skipUntilLevel = level
            }
        }
        return result
    }

    /// Markdown 内のリンクがクリックされたときの処理
    private func handleLinkTap(_ url: URL) -> OpenURLAction.Result {
        let scheme = url.scheme?.lowercased() ?? ""
        if ["http", "https", "mailto", "tel"].contains(scheme) {
            return .systemAction
        }
        let target: URL
        if scheme == "file" {
            target = url.standardizedFileURL
        } else {
            let raw = url.absoluteString.removingPercentEncoding ?? url.absoluteString
            if raw.hasPrefix("/") {
                target = URL(fileURLWithPath: raw).standardizedFileURL
            } else if let base = baseURL {
                target = base.appendingPathComponent(raw).standardizedFileURL
            } else {
                return .discarded
            }
        }
        guard FileManager.default.fileExists(atPath: target.path) else {
            return .discarded
        }
        onLinkTap?(target)
        return .handled
    }

    // MARK: - Render

    /// 1 行を View にレンダリング
    @ViewBuilder
    private func render(index: Int, line: MarkdownLine) -> some View {
        switch line {
        case .heading(let level, let text):
            headingRow(index: index, level: level, text: text)
        case .checkbox(let text, let checked, let indent):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                Text(.init(text))
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .bullet(let text, let indent):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(.init(text))
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .mermaid(let source):
            MermaidView(diagram: source)
        case .code(let text, let language):
            CodeBlockView(text: text, language: language, onRun: onRunScript)
        case .table(let header, let rows):
            tableView(header: header, rows: rows)
        case .paragraph(let text):
            Text(.init(text))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .frontmatter(let text):
            FrontmatterView(text: text, baseURL: baseURL, onLinkTap: onLinkTap)
        case .divider:
            Divider().padding(.vertical, 2)
        case .blank:
            Text("").frame(height: 4)
        }
    }

    /// 見出し行 (折りたたみトライアングル付き)
    @ViewBuilder
    private func headingRow(index: Int, level: Int, text: String) -> some View {
        let collapsed = collapsedHeadings.contains(index)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(collapsed ? 0 : 90))
            headingText(level: level, text: text)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                if collapsed {
                    collapsedHeadings.remove(index)
                } else {
                    collapsedHeadings.insert(index)
                }
            }
        }
        .padding(.top, level <= 2 ? 8 : 4)
    }

    /// 見出しレベルに応じたフォントでインラインコードスパンを等幅レンダリング
    private func headingText(level: Int, text: String) -> Text {
        let size: CGFloat
        let weight: Font.Weight
        switch level {
        case 1: size = 26; weight = .bold
        case 2: size = 22; weight = .bold
        case 3: size = 18; weight = .semibold
        case 4: size = 15; weight = .semibold
        default: size = 13; weight = .semibold
        }
        return Self.parseInlineSegments(text).reduce(Text("")) { result, segment in
            let t: Text = segment.isCode
                ? Text(segment.text).font(.system(size: size, weight: weight, design: .monospaced))
                : Text(.init(segment.text)).font(.system(size: size, weight: weight))
            return result + t
        }
    }

    /// テキストをバッククォートコードスパンで分割して (テキスト, コードフラグ) のリストを返す
    private static func parseInlineSegments(_ text: String) -> [(text: String, isCode: Bool)] {
        var segments: [(text: String, isCode: Bool)] = []
        var remaining = text
        while !remaining.isEmpty {
            guard let openIdx = remaining.firstIndex(of: "`") else {
                segments.append((remaining, false))
                break
            }
            let before = String(remaining[..<openIdx])
            if !before.isEmpty { segments.append((before, false)) }
            let rest = remaining[remaining.index(after: openIdx)...]
            guard let closeIdx = rest.firstIndex(of: "`") else {
                segments.append(("`" + String(rest), false))
                break
            }
            let code = String(rest[..<closeIdx])
            if !code.isEmpty { segments.append((code, true)) }
            remaining = String(rest[rest.index(after: closeIdx)...])
        }
        return segments
    }

    /// テーブル
    @ViewBuilder
    private func tableView(header: [String], rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack(spacing: 0) {
                ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                    Text(.init(cell))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(Color.secondary.opacity(0.15))
                }
            }
            // ボディ
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(.init(cell))
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                    }
                }
                .background(rowIndex.isMultiple(of: 2)
                            ? Color.clear
                            : Color.secondary.opacity(0.05))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.vertical, 4)
    }

    // MARK: - Table of contents

    /// 目次 (右上フローティング)
    @ViewBuilder
    private func tableOfContents(proxy: ScrollViewProxy) -> some View {
        let headings = collectHeadings()
        if !headings.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // ヘッダー: 全体がクリック可能領域 (折りたたみトグル)
                HStack {
                    Text("目次")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showTOC ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showTOC.toggle()
                    }
                }
                if showTOC {
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(headings, id: \.index) { heading in
                                TOCRow(
                                    heading: heading,
                                    onTap: {
                                        withAnimation {
                                            proxy.scrollTo("line-\(heading.index)", anchor: .top)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 300)
                }
            }
            // 展開時は幅 200、折りたたみ時は内容に合わせて縮める
            .frame(width: showTOC ? 200 : nil)
            .fixedSize(horizontal: !showTOC, vertical: false)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .padding(.top, 12)
            .padding(.trailing, 22) // スクロールバーと重ならないように余裕
            .padding(.leading, 12)
            .padding(.bottom, 12)
        }
    }

    /// 見出しだけ抽出する
    private func collectHeadings() -> [(index: Int, level: Int, text: String)] {
        lines.enumerated().compactMap { index, line in
            if case .heading(let level, let text) = line {
                return (index, level, text)
            }
            return nil
        }
    }

    // MARK: - Parser

    /// テキストを行ベースでパースして MarkdownLine 配列を返す
    static func parseLines(_ source: String) -> [MarkdownLine] {
        var result: [MarkdownLine] = []
        var inCodeBlock = false
        var codeBuffer: [String] = []
        var isMermaidBlock = false
        var currentLang: String = ""
        var inFrontmatter = false
        var frontmatterBuffer: [String] = []

        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var i = 0
        while i < rawLines.count {
            let raw = rawLines[i]

            // Frontmatter (先頭の --- から次の --- まで)
            if i == 0, raw.trimmingCharacters(in: .whitespaces) == "---" {
                inFrontmatter = true
                i += 1
                continue
            }
            if inFrontmatter {
                if raw.trimmingCharacters(in: .whitespaces) == "---" {
                    result.append(.frontmatter(frontmatterBuffer.joined(separator: "\n")))
                    frontmatterBuffer = []
                    inFrontmatter = false
                } else {
                    frontmatterBuffer.append(raw)
                }
                i += 1
                continue
            }

            // コードブロック (``` で開閉)
            if raw.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCodeBlock {
                    let content = codeBuffer.joined(separator: "\n")
                    result.append(isMermaidBlock ? .mermaid(content) : .code(content, language: currentLang))
                    codeBuffer = []
                    inCodeBlock = false
                    isMermaidBlock = false
                    currentLang = ""
                } else {
                    let lang = String(raw.trimmingCharacters(in: .whitespaces).dropFirst(3))
                        .trimmingCharacters(in: .whitespaces).lowercased()
                    currentLang = lang
                    isMermaidBlock = lang == "mermaid"
                    inCodeBlock = true
                }
                i += 1
                continue
            }
            if inCodeBlock {
                codeBuffer.append(raw)
                i += 1
                continue
            }

            // テーブル (| col | col | + 区切り + 行)
            if raw.trimmingCharacters(in: .whitespaces).hasPrefix("|"),
               i + 1 < rawLines.count,
               Self.isTableSeparatorLine(rawLines[i + 1]) {
                let header = Self.parseTableRow(raw)
                var rows: [[String]] = []
                var j = i + 2
                while j < rawLines.count,
                      rawLines[j].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    rows.append(Self.parseTableRow(rawLines[j]))
                    j += 1
                }
                result.append(.table(header: header, rows: rows))
                i = j
                continue
            }

            // 見出し
            if raw.hasPrefix("#### ") {
                result.append(.heading(level: 4, text: String(raw.dropFirst(5))))
                i += 1
                continue
            }
            if raw.hasPrefix("### ") {
                result.append(.heading(level: 3, text: String(raw.dropFirst(4))))
                i += 1
                continue
            }
            if raw.hasPrefix("## ") {
                result.append(.heading(level: 2, text: String(raw.dropFirst(3))))
                i += 1
                continue
            }
            if raw.hasPrefix("# ") {
                result.append(.heading(level: 1, text: String(raw.dropFirst(2))))
                i += 1
                continue
            }

            // 水平線
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(.divider)
                i += 1
                continue
            }

            // 箇条書き (チェックボックス含む)
            if let (indent, content) = Self.parseBullet(raw) {
                if let (checked, text) = Self.parseCheckbox(content) {
                    result.append(.checkbox(text: text, checked: checked, indent: indent))
                } else {
                    result.append(.bullet(text: content, indent: indent))
                }
                i += 1
                continue
            }

            // 空行
            if trimmed.isEmpty {
                result.append(.blank)
                i += 1
                continue
            }

            // 通常段落
            result.append(.paragraph(raw))
            i += 1
        }

        if !codeBuffer.isEmpty {
            let content = codeBuffer.joined(separator: "\n")
            result.append(isMermaidBlock ? .mermaid(content) : .code(content, language: currentLang))
        }
        if !frontmatterBuffer.isEmpty {
            result.append(.frontmatter(frontmatterBuffer.joined(separator: "\n")))
        }

        return result
    }

    /// テーブル区切り行 `|---|---|` かどうか
    private static func isTableSeparatorLine(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|") else { return false }
        let cells = t.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            // `-` のみ、または `:---`, `---:`, `:---:` 等
            let stripped = cell.replacingOccurrences(of: ":", with: "")
            return !stripped.isEmpty && stripped.allSatisfy { $0 == "-" }
        }
    }

    /// `| a | b | c |` をセル配列にパースする
    private static func parseTableRow(_ raw: String) -> [String] {
        var t = raw.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// 箇条書き行をパースする (`- text` / `  * text` 等)
    private static func parseBullet(_ raw: String) -> (indent: Int, content: String)? {
        var indent = 0
        var index = raw.startIndex
        while index < raw.endIndex, raw[index] == " " {
            indent += 1
            index = raw.index(after: index)
        }
        let rest = String(raw[index...])
        if rest.hasPrefix("- ") {
            return (indent / 2, String(rest.dropFirst(2)))
        }
        if rest.hasPrefix("* ") {
            return (indent / 2, String(rest.dropFirst(2)))
        }
        return nil
    }

    /// 箇条書き内容がチェックボックス形式か判定し、`(checked, text)` を返す
    private static func parseCheckbox(_ content: String) -> (checked: Bool, text: String)? {
        if content.hasPrefix("[ ] ") {
            return (false, String(content.dropFirst(4)))
        }
        if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
            return (true, String(content.dropFirst(4)))
        }
        return nil
    }
}

/// YAML frontmatter の 1 行を表す中間表現。
private enum FrontmatterLineContent {
    case plain(String)
    case withLink(prefix: String, path: String, resolvedURL: URL)
}

/// YAML frontmatter ブロックを行ごとにレンダリングする View。
/// ファイルパスと判定された値はクリック可能なリンクとして表示し、タップで隣タブに開く。
private struct FrontmatterView: View {
    let text: String
    let baseURL: URL?
    let onLinkTap: ((URL) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(parsedLines.enumerated()), id: \.offset) { pair in
                FrontmatterLineView(content: pair.element, onLinkTap: onLinkTap)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var parsedLines: [FrontmatterLineContent] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .map { parseLine($0) }
    }

    private func parseLine(_ line: String) -> FrontmatterLineContent {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indent = String(line.prefix(while: { $0 == " " }))

        // "  - value" 形式 (YAML 配列項目)
        if trimmed.hasPrefix("- ") {
            let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if looksLikeFilePath(value), let url = resolveURL(value) {
                return .withLink(prefix: indent + "- ", path: value, resolvedURL: url)
            }
        } else if let colonIndex = trimmed.firstIndex(of: ":") {
            // "key: value" 形式
            let rest = trimmed[trimmed.index(after: colonIndex)...]
            let afterColon = String(rest).trimmingCharacters(in: .whitespaces)
            if looksLikeFilePath(afterColon), let url = resolveURL(afterColon) {
                let key = String(trimmed[..<colonIndex])
                return .withLink(prefix: indent + key + ": ", path: afterColon, resolvedURL: url)
            }
        }
        return .plain(line)
    }

    private func looksLikeFilePath(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        guard !value.hasPrefix("http"), !value.hasPrefix("["), !value.hasPrefix("{") else { return false }
        return value.contains("/")
    }

    private func resolveURL(_ path: String) -> URL? {
        guard let base = baseURL else { return nil }
        let fm = FileManager.default
        // ファイルの親ディレクトリから相対パスを試みる
        let direct = base.appendingPathComponent(path).standardizedFileURL
        if fm.fileExists(atPath: direct.path) { return direct }
        // 親ディレクトリをさかのぼって探す (上限 10 段)
        var dir = base
        for _ in 0..<10 {
            let parent = dir.deletingLastPathComponent()
            guard parent != dir else { break }
            dir = parent
            let candidate = dir.appendingPathComponent(path).standardizedFileURL
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }
}

/// frontmatter の 1 行を表示する View。
private struct FrontmatterLineView: View {
    let content: FrontmatterLineContent
    let onLinkTap: ((URL) -> Void)?

    var body: some View {
        switch content {
        case .plain(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .withLink(let prefix, let path, let resolvedURL):
            HStack(spacing: 0) {
                Text(prefix)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button(path) {
                    onLinkTap?(resolvedURL)
                }
                .buttonStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color.accentColor)
                .underline()
                Spacer(minLength: 0)
            }
        }
    }
}

/// 目次の 1 行。ホバー時にアクセントカラー背景でハイライト表示する。
private struct TOCRow: View {
    let heading: (index: Int, level: Int, text: String)
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(heading.text.replacingOccurrences(of: "`", with: ""))
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(isHovered ? Color.white : Color.primary)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8 + CGFloat(heading.level - 1) * 10)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(isHovered ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovered in
            isHovered = hovered
        }
        .onTapGesture { onTap() }
    }
}

/// コードブロックを表示する View。シェル言語の場合は右上に実行ボタンを表示する。
/// 実行時のコールバックは onRun で受け取る (onLinkTap と同じパターン)。
private struct CodeBlockView: View {
    let text: String
    let language: String
    let onRun: ((String) -> Void)?

    private static let shellLanguages: Set<String> = [
        "bash", "sh", "zsh", "shell", "fish", "ksh", "csh", "tcsh"
    ]

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.12))
            )
            .overlay(alignment: .topTrailing) {
                if let onRun, Self.shellLanguages.contains(language) {
                    Button {
                        onRun(text)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
    }
}

/// Markdown の行種別を表す中間表現
enum MarkdownLine {
    case heading(level: Int, text: String)
    case bullet(text: String, indent: Int)
    case checkbox(text: String, checked: Bool, indent: Int)
    case code(String, language: String)
    case mermaid(String)
    case table(header: [String], rows: [[String]])
    case paragraph(String)
    case frontmatter(String)
    case divider
    case blank
}
