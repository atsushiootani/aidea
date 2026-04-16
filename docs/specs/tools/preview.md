# Tool 仕様: Preview

ファイルを読み取り専用で表示する Tool。Kit や Filer から `SessionRegistry.openPreview(for:title:)` 経由で呼ばれる。
実装: `Aidea/Sessions/Preview/` と `Aidea/Views/Sessions/Preview/` 配下。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/preview.md](../sessions/preview.md) を参照。
共通 UI 規約は [sessions/ui-rules.md](../sessions/ui-rules.md) と [window/](../window/README.md) を参照。

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
| `.drawio.svg` / `.drawio` | `DrawioPreview` (後述) | 実装済 |
| テキスト全般 (バイナリ判定で NUL を含まない) | `NSTextPreview` (NSTextView ラッパ) | 実装済 |
| サイズ > 1MB | "ファイルが大きすぎます" メッセージ | 実装済 |
| バイナリ (NUL を含む) | "プレビュー非対応のバイナリ" メッセージ | 実装済 |

---

## 機能

### openFile — ファイルを開く
- `SessionRegistry.openPreview(for:title:)` 経由で呼ばれる
- state.url を更新 → ハンドラが自動判定
- 既存 Preview に同じ URL がある場合は新規作成せずアクティブ化 (openPreview が dedupe)
- 詳細は [sessions/active-session.md#preview-を開くときの呼び出し規約](../sessions/active-session.md#preview-を開くときの呼び出し規約) を参照

### renderMarkdown — Markdown を見やすく表示
- `.md` / `.markdown` を `MarkdownPreview` で表示
- 見出し (`# ~ ####`) / コードブロック / 箇条書き / 水平線 / frontmatter / インライン (bold・italic・リンク・`code`) をサポート
- 外部依存なし (SwiftUI `Text(.init(String))` のネイティブ Markdown に委譲)

### translateToJapanese — 英語ドキュメントの日本語翻訳

英語の Markdown / テキストファイルを Claude API で日本語に翻訳し、`.aidea/ja/` にキャッシュする。

#### フロー

1. `LanguageDetector` が先頭 1000 文字をサンプルし英語と判定 → 右上に「日本語」ボタンを表示
2. ボタン押下 → `TranslationService` が `TranslationCache` でキャッシュの有無と鮮度 (mtime 比較) を確認
3. キャッシュが新鮮ならそのまま表示。古い or 無ければ Claude API で翻訳
4. `ClaudeTranslator` が `claude-haiku-4-5-20251001` に翻訳リクエスト (Markdown 構造・コード識別子は保持)
5. 翻訳結果を `.aidea/ja/<相対パス>/<filename>` に保存
6. 翻訳版を sibling タブで開く (タイトルに「(日本語)」付与)

#### API キー設定

- Anthropic API キーを **macOS Keychain** に保存 (サービス: `com.aidea.anthropic-api-key`)
- 初回翻訳時またはメニュー「Aidea → API キー設定...」で NSSecureTextField ダイアログを表示

#### 実装ファイル

| ファイル | 役割 |
|---|---|
| `Services/Translation/TranslationService.swift` | キャッシュ確認 → API 呼び出し → 保存のオーケストレーション |
| `Services/Translation/ClaudeTranslator.swift` | Claude API (URLSession) との通信、API キー管理 |
| `Services/Translation/TranslationCache.swift` | `.aidea/ja/` のキャッシュ管理、mtime 鮮度判定 |
| `Services/Translation/LanguageDetector.swift` | NLLanguageRecognizer による英語判定 |

#### UI 表示箇所

- `MarkdownContainer` — Markdown 表示時の右上フローティングボタン
- `PreviewSessionView` — テキストファイル表示時の翻訳ボタン

### renderImage — 画像表示
- 対応拡張子を `NSImage` でロードして `ScrollView` + `Image(nsImage:)` で表示

### renderDrawio — drawio 図の表示・編集

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
| **Cmd + E** | drawio ファイル表示時に編集モードへトグル |
| **Esc** | drawio 編集モードをキャンセルしてプレビューへ戻る |

---

## 受け入れ基準 (Acceptance Criteria)

### 既存 (実装済)
- [x] テキストファイルを NSTextView で表示
- [x] 1MB 超 / バイナリは警告表示
- [x] 画像ファイルを NSImage で表示
- [x] `.md` ファイルを Markdown としてレンダリング

### drawio (実装済)
- [x] `.drawio.svg` ファイルを Preview Session で開くと静的な図が表示される
- [x] 右上に `✎ Edit` ボタンが表示される
- [x] Edit ボタン押下で drawio エディタ (embed.diagrams.net) が同じペイン内に表示される
- [x] 既存の XML がエディタにロードされる
- [x] エディタ上で編集できる
- [x] 保存ボタンで元ファイルに書き戻し、プレビューモードに戻る
- [x] キャンセルボタンで編集内容を破棄
- [x] `.drawio` (純 XML) もサポート (`DrawioStaticView` が `embed.diagrams.net` chrome=0 でレンダリング)

---

## 実装メモ

### 既存コード
- `PreviewSessionState.url: URL?` `title: String?` を保持
- `PreviewSessionView` が state.url の拡張子を見て SwiftUI 分岐

### drawio 実装ファイル
- `Views/Sessions/Preview/DrawioPreview.swift` — View/Edit モード切替、保存/キャンセル UI
- `Views/Sessions/Preview/DrawioStaticView.swift` — `.drawio.svg` の静的表示 / `.drawio` の chrome=0 レンダリング
- `Views/Sessions/Preview/DrawioEditor.swift` — `embed.diagrams.net` embed mode の WKWebView ラッパ、postMessage プロトコル仲介

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
