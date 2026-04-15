# Tool 仕様: Preview

ファイルを読み取り専用で表示する Tool。Kit や Filer から `SessionRegistry.openPreview(for:title:)` 経由で呼ばれる。
実装: `Aidea/Sessions/Preview/` と `Aidea/Views/Sessions/Preview/` 配下。

概念モデルは [session/concept-model.md](../session/concept-model.md) / [glossary.md](../glossary.md) を参照。
共通 UI 規約は [boundaries.md](../boundaries.md#ui-conventions-ui-共通ルール) を参照。

---

## 概要

- Preview Session は 1 つのファイルを表示する
- ファイルの種別に応じて **コンテンツハンドラ**を切り替える (同じ Preview Session で複数の種別を透過的に扱う)
- タブタイトルは `PreviewSessionState.title` があればそれ、無ければ URL の最終要素
- Preview は Window 内に複数インスタンス同時存在可

## ファイル種別とコンテンツハンドラ

| 拡張子 / 条件 | ハンドラ | 状態 |
|---|---|---|
| `.md` / `.markdown` | `MarkdownPreview` (軽量 SwiftUI パーサ) | 実装済 |
| `.png` `.jpg` `.jpeg` `.gif` `.heic` `.webp` `.bmp` | `NSImage` + `Image(nsImage:)` | 実装済 |
| `.drawio.svg` / `.drawio` | `DrawioPreview` (後述) | 未実装 |
| テキスト全般 (バイナリ判定で NUL を含まない) | `NSTextPreview` (NSTextView ラッパ) | 実装済 |
| サイズ > 1MB | "ファイルが大きすぎます" メッセージ | 実装済 |
| バイナリ (NUL を含む) | "プレビュー非対応のバイナリ" メッセージ | 実装済 |

---

## 機能

### openFile — ファイルを開く
- `SessionRegistry.openPreview(for:title:)` 経由で呼ばれる
- state.url を更新 → ハンドラが自動判定
- 既存 Preview に同じ URL がある場合は新規作成せずアクティブ化 (openPreview が dedupe)
- 詳細は [boundaries.md Preview を開くときの規約](../boundaries.md#preview-を開くときの規約) を参照

### renderMarkdown — Markdown を見やすく表示
- `.md` / `.markdown` を `MarkdownPreview` で表示
- 見出し (`# ~ ####`) / コードブロック / 箇条書き / 水平線 / frontmatter / インライン (bold・italic・リンク・`code`) をサポート
- 外部依存なし (SwiftUI `Text(.init(String))` のネイティブ Markdown に委譲)

### renderImage — 画像表示
- 対応拡張子を `NSImage` でロードして `ScrollView` + `Image(nsImage:)` で表示

### renderDrawio — drawio 図の表示・編集 (新規・将来実装)

drawio ファイル (`.drawio.svg` / `.drawio`) を **プレビューと編集の 2 モード**で扱う。
Obsidian の drawio プラグインと同等の UX を目指す。

#### プレビューモード (初期表示)
- `.drawio.svg` の場合: SVG 部分を `NSImage` で表示 (drawio ファイルはそのまま有効な SVG)
- `.drawio` の場合: XML のみなので SVG 表現がない → **初回は WKWebView で drawio エディタを隠れた状態で動かして SVG を export** してキャッシュ表示
  (MVP では `.drawio` サポートは後回し、まず `.drawio.svg` を優先)
- 右上に **`✎ Edit` ボタン**

#### 編集モード (Edit ボタン押下)
- `WKWebView` に **`https://embed.diagrams.net/?embed=1&ui=dark&spin=1&proto=json`** をロード
- `postMessage` で drawio に現ファイルの XML を送る (action: `load`)
- drawio エディタが表示され、ユーザーが自由に編集できる
- 上部に **`✓ 保存` / `✗ キャンセル`** ボタン
- 保存時: drawio から `action: save` の postMessage を受け取り、新 XML を取得 → 元ファイルに書き戻し (`.drawio.svg` 形式を維持)
- キャンセル時: 編集内容を破棄してプレビューモードに戻る

#### 保存時の .drawio.svg 形式維持
- `.drawio.svg` は `<svg>` タグに `content="<drawio XML>"` 属性を持つ形式
- drawio の export 結果の SVG を書き戻す (drawio 側が正しい形式で返す)

#### 通信プロトコル (drawio embed)
- drawio embed mode は `window.postMessage` ベース
- Aidea (WKWebView) → drawio: `{action: "load", xml: "<xml>"}`
- drawio → Aidea: `{event: "init"}`, `{event: "save", xml: "...", data: "..."}`, `{event: "exit"}`
- 詳細: https://www.drawio.com/doc/faq/embed-mode

---

## キーボード操作

| キー | 機能 |
|---|---|
| **Ctrl + P / N / F / B / V / Z** | テキスト/Markdown 表示時はスクロール、drawio は drawio 側に任せる |
| **Cmd + E** | drawio ファイル表示時に編集モードへトグル (将来) |
| **Esc** | drawio 編集モードをキャンセルしてプレビューへ戻る (将来) |

---

## 受け入れ基準 (Acceptance Criteria)

### 既存 (実装済)
- [x] テキストファイルを NSTextView で表示
- [x] 1MB 超 / バイナリは警告表示
- [x] 画像ファイルを NSImage で表示
- [x] `.md` ファイルを Markdown としてレンダリング

### 新規 (drawio)
- [ ] `.drawio.svg` ファイルを Preview Session で開くと静的な図が表示される
- [ ] 右上に `✎ Edit` ボタンが表示される
- [ ] Edit ボタン押下で drawio エディタ (embed.diagrams.net) が同じペイン内に表示される
- [ ] 既存の XML がエディタにロードされる
- [ ] エディタ上で編集できる
- [ ] 保存ボタンで元ファイルに書き戻し、プレビューモードに戻る
- [ ] FSEvents でファイラが更新を検知する (filer のツリーで確認可)
- [ ] キャンセルボタンで編集内容を破棄
- [ ] `.drawio` (純 XML) もサポート (Phase 2 で対応でも可)

---

## 実装メモ

### 既存コード
- `PreviewSessionState.url: URL?` `title: String?` を保持
- `PreviewSessionView` が state.url の拡張子を見て SwiftUI 分岐

### drawio 実装予定
- `Views/Sessions/Preview/DrawioPreview.swift` を新規追加
  - `mode: .view | .edit` をローカル `@State` で持つ
  - `.view` のとき: `Image(nsImage: NSImage(contentsOf: url))` + Edit ボタン
  - `.edit` のとき: `DrawioEditor` (WKWebView ラッパ) + 保存/キャンセルボタン
- `Views/Sessions/Preview/DrawioEditor.swift` を新規追加
  - `WKWebView` を `NSViewRepresentable` でラップ
  - `WKScriptMessageHandler` で drawio からの postMessage を受信
  - `evaluateJavaScript` で drawio に JSON コマンドを送信
  - drawio の init イベント受信後に load コマンドで XML を注入
  - save イベント受信で `FileManager.default.write` or `String.write(to:atomically:encoding:)` でファイル書き戻し
- `PreviewSessionView` の switch に `.drawio.svg` / `.drawio` 分岐を追加

### 依存追加の有無
- **外部依存追加なし** (embed.diagrams.net をオンラインで使用、WebKit は既に使用中)
- オフライン対応は将来検討

---

## 未検討事項 (将来)

- `.drawio` (純 XML) のプレビュー (初回 SVG 生成ロジック)
- 新規 drawio ファイル作成 (Filer の Cmd+N からテンプレート生成)
- オフライン対応 (drawio HTML/JS を Aidea にバンドル)
- ダーク/ライトテーマ同期 (現状は `ui=dark` 固定)
- 複数ページ drawio の扱い
- 画像 (png/jpg) の編集 (drawio は対応しない)
