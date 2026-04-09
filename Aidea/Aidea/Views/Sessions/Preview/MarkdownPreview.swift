//
//  MarkdownPreview.swift
//  Aidea
//

import SwiftUI

/// Markdown テキストを見やすく表示する SwiftUI View。
/// 行ベースのシンプルなパーサで以下をサポート:
/// - `# / ## / ### / ####` 見出し
/// - `` ``` `` フェンス付きコードブロック
/// - `- ` / `* ` 箇条書き
/// - 通常段落 (インラインの `**bold**` `*italic*` `[link](url)` `` `code` `` は
///   SwiftUI `Text(.init(String))` のネイティブ Markdown パースに任せる)
/// - YAML frontmatter (`---` で囲まれたブロック) は薄く表示
struct MarkdownPreview: View {
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    render(line)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }

    /// テキストを 1 行ずつパースした Markdown ラインの配列
    private var lines: [MarkdownLine] {
        parseLines(text)
    }

    /// 1 行を対応する View にレンダリング
    @ViewBuilder
    private func render(_ line: MarkdownLine) -> some View {
        switch line {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .bullet(let text, let indent):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(.init(text))
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .code(let text):
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                )
        case .paragraph(let text):
            Text(.init(text))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .frontmatter(let text):
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.08))
                )
        case .divider:
            Divider().padding(.vertical, 2)
        case .blank:
            Text("").frame(height: 4)
        }
    }

    /// 見出しレベルに応じたフォント設定
    @ViewBuilder
    private func headingView(level: Int, text: String) -> some View {
        let view = Text(.init(text))
        switch level {
        case 1: view.font(.system(size: 26, weight: .bold)).padding(.top, 8)
        case 2: view.font(.system(size: 22, weight: .bold)).padding(.top, 6)
        case 3: view.font(.system(size: 18, weight: .semibold)).padding(.top, 4)
        case 4: view.font(.system(size: 15, weight: .semibold)).padding(.top, 2)
        default: view.font(.system(size: 13, weight: .semibold))
        }
    }

    /// テキストを行ベースでパースして MarkdownLine 配列を返す
    private func parseLines(_ source: String) -> [MarkdownLine] {
        var result: [MarkdownLine] = []
        var inCodeBlock = false
        var codeBuffer: [String] = []
        var inFrontmatter = false
        var frontmatterBuffer: [String] = []

        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for (index, raw) in rawLines.enumerated() {
            // Frontmatter (先頭の --- から次の --- まで)
            if index == 0, raw.trimmingCharacters(in: .whitespaces) == "---" {
                inFrontmatter = true
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
                continue
            }

            // コードブロック (``` で開閉)
            if raw.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCodeBlock {
                    result.append(.code(codeBuffer.joined(separator: "\n")))
                    codeBuffer = []
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                codeBuffer.append(raw)
                continue
            }

            // 見出し
            if raw.hasPrefix("#### ") {
                result.append(.heading(level: 4, text: String(raw.dropFirst(5))))
                continue
            }
            if raw.hasPrefix("### ") {
                result.append(.heading(level: 3, text: String(raw.dropFirst(4))))
                continue
            }
            if raw.hasPrefix("## ") {
                result.append(.heading(level: 2, text: String(raw.dropFirst(3))))
                continue
            }
            if raw.hasPrefix("# ") {
                result.append(.heading(level: 1, text: String(raw.dropFirst(2))))
                continue
            }

            // 水平線
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(.divider)
                continue
            }

            // 箇条書き (インデント対応)
            if let (indent, content) = parseBullet(raw) {
                result.append(.bullet(text: content, indent: indent))
                continue
            }

            // 空行
            if trimmed.isEmpty {
                result.append(.blank)
                continue
            }

            // 通常段落
            result.append(.paragraph(raw))
        }

        // 閉じていないコードブロック/frontmatter のフラッシュ
        if !codeBuffer.isEmpty {
            result.append(.code(codeBuffer.joined(separator: "\n")))
        }
        if !frontmatterBuffer.isEmpty {
            result.append(.frontmatter(frontmatterBuffer.joined(separator: "\n")))
        }

        return result
    }

    /// 箇条書き行をパースする (`- text` / `  * text` 等)。インデントレベルと本文を返す。
    private func parseBullet(_ raw: String) -> (indent: Int, content: String)? {
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
}

/// Markdown の行種別を表す中間表現
enum MarkdownLine {
    case heading(level: Int, text: String)
    case bullet(text: String, indent: Int)
    case code(String)
    case paragraph(String)
    case frontmatter(String)
    case divider
    case blank
}
