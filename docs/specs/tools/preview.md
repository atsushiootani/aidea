---
title: Tool 仕様: Preview
description: Markdown / 画像 / 動画 / drawio / テキストを読み取り専用で表示し、英語ドキュメントの日本語翻訳キャッシュも担う Preview Tool 仕様
derived_from:
  - docs/decisions/0010-drawio-rendering-paths.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/sessions/active-session.md
  - docs/specs/window/
syncs_with:
  - docs/specs/sessions/preview.md
  - docs/specs/aspects/keybindings.md
  - docs/specs/aspects/persistence.md
  - docs/specs/tools/terminal.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-27
---

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
| `.mp4` `.mov` `.m4v` `.mkv` `.avi` | `VideoPreview` (AVKit プレーヤー) | 実装済 |
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
- 見出し (`# ~ ####`) / コードブロック / Mermaid 図 / 箇条書き / 水平線 / frontmatter / インライン (bold・italic・リンク・`code`) をサポート
- 外部依存なし (SwiftUI `Text(.init(String))` のネイティブ Markdown に委譲)

#### runShellScript — シェルスクリプトコードブロックの実行

- view モードで表示中のシェルスクリプトコードブロック右上に `▶` 実行ボタンを表示する
- 対象言語: `bash` / `sh` / `zsh` / `shell` / `fish` / `ksh` / `csh` / `tcsh`
- 実行ボタン押下時の挙動:
  - 既存の Terminal セッションがあれば、そのタブをアクティブ化してコマンドを PTY へ送信する
  - Terminal セッションがなければ、新規 Terminal タブを作成してシェル起動後 (800ms 待機) にコマンドを送信する
- edit モード中は実行ボタンを表示しない (コードブロックはテキストとして編集する)

#### 見出し内インラインコード

- 見出し行 (`` # ~ #### ``) 内のバッククォートコードスパン (`` `code` ``) は等幅フォントで表示する
- 見出しの文字サイズ・ウェイトはそのままに、コードスパン部分のみ `monospaced` デザインを適用する
- コードスパン部分には薄いグレー背景 (`Color.secondary.opacity(0.15)`) と角丸 (radius 3) を付与し、インラインコードブロックと視覚的に一貫したスタイルにする
- 目次 (ToC) 表示では、バッククォート記号を除いたプレーンテキストで表示する

#### frontmatter 表示

- フォント: 本文と同サイズ (`.body`) のモノスペースフォント
- 背景: `Color.secondary.opacity(0.08)` のラウンドコーナーブロック
- YAML 行を `key: value` および配列項目 `  - value` の形式で行ごとに解析する
- **ファイルパスのクリック**: 値がローカルファイルパスと判定される場合 (`/` を含み `http` / `[` / `{` で始まらない) はリンクとして表示し、タップすると隣タブで Preview が開く
- パス解決順: ① ファイルの親ディレクトリからの相対パス → ② 親を順にさかのぼって最初に一致するパス (上限 10 段) → 見つからなければリンク非表示

#### Mermaid 図の表示

- Markdown 内の ` ```mermaid ... ``` ` ブロックを Mermaid 図として描画する
- **view モード**: `MermaidView` (WKWebView + CDN の Mermaid.js) でレンダリング。描画完了後に高さを自動調整
- **edit モード**: 通常のコードブロックとして表示 (生テキスト)
- パース失敗時はエラーメッセージを赤文字で表示
- ネットワーク接続が必要 (drawio embed と同様、オフライン対応は将来検討)
- 実装: `MermaidView` (WKWebView + Mermaid.js)

#### view / edit モード切替 UI

Markdown は `MarkdownContainer` で **view / edit の 2 モード**を扱う。右上にフローティングで **アイコンのみのセグメントコントロール** を配置し、ユーザーはワンタップで切り替えられる。

| モード | SF Symbols | 意味 |
|---|---|---|
| **view** | `eye` | プレビュー表示 (純 SwiftUI `MarkdownPreview`) |
| **edit** | `chevron.left.forwardslash.chevron.right` | 編集 (NSTextView の `EditableTextView`) |

- **表示形式**: SwiftUI `Picker` の `.segmented` スタイル。ラベルはアイコンのみ (テキストなし) で `Image(systemName:)` を使う
- **操作**: セグメントタップで即座にモード切替。edit → view に戻すときは、未保存の draftText を **切替直前に flush 保存** してから view に遷移する (500ms デバウンスの自動保存と同じ経路)
- **配置**: 既存の右上フローティング位置 (padding top 10 / trailing 22) を維持
- **キーボード**: view モードで `E` を押すと edit に切替 (セグメントボタンと等価)。既存仕様維持
- **翻訳「日本語」ボタン**: 従来どおりセグメントコントロールの下に配置される (表示条件は `mode == .view && isEnglish && !isCachedFile`)

#### キャッシュファイル (`.aidea/ja/`) の扱い

`.aidea/ja/` 配下の翻訳キャッシュファイルはユーザーの編集対象外のため、**セグメントコントロールは表示しない**。代わりに「英語」ボタン (SF Symbols `character.book.closed`) のみを表示し、押すと元の英語ファイルを sibling タブで開く。

### translateToJapanese — 英語ドキュメントの日本語翻訳

英語の Markdown / テキストファイルを Claude API で日本語に翻訳し、`.aidea/ja/` にキャッシュする。

#### フロー

1. `LanguageDetector` が先頭 1000 文字をサンプルし英語と判定 → 右上に「日本語」ボタンを表示
2. ボタン押下 → `TranslationService` が `TranslationCache` でキャッシュの有無と鮮度 (mtime 比較) を確認
3. キャッシュが新鮮ならそのまま表示。古い or 無ければ Claude API で SSE ストリーミング翻訳
4. `ClaudeTranslator` が `claude-haiku-4-5-20251001` に `stream: true` でリクエスト送信 (Markdown 構造・コード識別子は保持)
5. チャンク受信のたびに `.aidea/ja/<相対パス>/<filename>` へ累積テキストを書き込む
6. 最初のチャンク受信時に sibling タブを開く → FileWatcher がその後の書き込みを検知して表示を逐次更新
7. 翻訳完了 (ストリーム終端) 後にボタン状態を完了に更新する

#### ストリーミング (SSE)

- `URLSession.bytes(for:)` で行単位に SSE イベントを受信する (タイムアウト不要)
- `data: {...}` 行のみ処理し、`type == "content_block_delta"` かつ `delta.type == "text_delta"` の `delta.text` を取り出す
- エラー終了時はキャッシュファイルを削除して不完全なキャッシュを残さない

#### 進捗 UI

- 翻訳中はボタンラベルを「翻訳中... (N 文字)」に更新する (N = 累積受信文字数)
- 最初のチャンク受信前は「翻訳中...」のみ表示

#### API キー設定

- Anthropic API キーを **macOS Keychain** に保存 (サービス: `com.aidea.anthropic-api-key`)
- 初回翻訳時またはメニュー「Aidea → API キー設定...」で NSSecureTextField ダイアログを表示

#### 実装コンポーネント

| コンポーネント | 役割 |
|---|---|
| `TranslationService` | キャッシュ確認 → API 呼び出し → 保存のオーケストレーション |
| `ClaudeTranslator` | Claude API との通信、API キー管理 |
| `TranslationCache` | `.aidea/ja/` のキャッシュ管理、mtime 鮮度判定 |
| `LanguageDetector` | 言語識別による英語判定 |

#### UI 表示箇所

- `MarkdownContainer` — Markdown 表示時の右上フローティングボタン
- `PreviewSessionView` — テキストファイル表示時の翻訳ボタン

### autoReload — 外部変更の自動再読み込み

プレビュー表示中のファイルが外部 (Claude など) によって変更されたとき、プレビュー表示を自動的に更新する。

- ファイルの変更は **FSEvents** で検知する (実装: 既存の `FileWatcher` を流用)
- 変更を検知したら直ちにファイルを再読み込みしてプレビューを更新する
- **編集モード中は更新しない**: `MarkdownContainer` が edit モードのときはスキップし、view モードに戻ったタイミングで反映される
- 対象: Markdown (`MarkdownContainer` の view モード) とテキスト / 画像ファイル (`NSTextPreview` / `NSImage`)
- Drawio ファイルは対象外 (embed.diagrams.net のエディタが外部状態を持つため)

### tabHoverTooltip — タブホバー時のパス表示

Preview タブにマウスカーソルを合わせると、ツールチップでファイルのパスを表示する。

- `workspace.projectRoot` が設定されており `preview.url` がその配下にある場合: プロジェクトルートからの相対パスを表示 (例: `docs/specs/tools/preview.md`)
- `preview.url` が projectRoot 配下にない場合、または projectRoot 未設定の場合: 絶対パスを表示
- `preview.url` が nil の場合: ツールチップなし

### タブ右クリックメニュー (issue #238)

Preview タブを右クリックすると、コンテキストメニューを表示する。対象は `preview.url` を持つ Preview タブのみで、
url が無いタブ・Preview 以外のタブにはメニューを出さない (空メニューを表示しない)。共通の右クリック規約は
[sessions/ui-rules.md#右クリックコンテキストメニュー](../sessions/ui-rules.md#右クリック・コンテキストメニュー) に従う。

| 項目 | 動作 |
|---|---|
| タブ名を変更 | タブのインラインリネームを開始する (タブのダブルクリックと同じ。`startRename`) |
| ファイル名をコピー | `url.lastPathComponent` をクリップボードにコピー |
| プロジェクト相対パスをコピー | projectRoot 相対パス (ツールチップと同じ算出) をコピー。projectRoot 外/未設定なら絶対パス |
| 絶対パスをコピー | `url.standardizedFileURL.path` をコピー |
| ファイラで選択 | Filer セッションで当該ファイルを選択し、**スクロール位置を中央に寄せて** フォーカスする |
| タブを閉じる | このタブを閉じる (`closeTab`) |

- クリップボード書き込みは `NSPasteboard.general` を `clearContents()` してから `setString(_:forType: .string)`
- 「ファイラで選択」は `SessionRegistry.revealInFiler(_:)` 経由で Filer の `FileTreeViewController.focusOnURL(_:centered:)` を呼ぶ。
  親ディレクトリを展開して対象行を選択し、`scrollRowToVisible` ではなく**中央寄せスクロール**で表示する。
  Filer セッションが存在しない場合は何もしない

### renderImage — 画像表示
- 対応拡張子を `NSImage` でロードして `ScrollView` + `Image(nsImage:)` で表示

### renderVideo — 動画再生

`.mp4` / `.mov` / `.m4v` / `.mkv` / `.avi` を AVKit のネイティブプレーヤーで表示する。

- 再生・停止・シークバー・音量などの標準コントロールを表示する
- ファイルを開いた時点で再生を開始しない (ユーザーが再生ボタンを押してから再生)
- タブを切り替えるなどビューが非表示になったとき、再生を自動停止する
- 動画ファイルはサイズ制限 (1 MB) および バイナリ判定を適用しない (ファイルは直接 AVPlayer へ渡す)

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

### openFromExternal — 外部アプリからファイルを開く (URL スキーム)

Aidea は `aidea://` カスタム URL スキームを登録する。
外部アプリ (Claude Code のトランスクリプトビューア等) から Aidea でファイルを開くために使用する。

#### URL 形式

```
aidea://open?path=<パーセントエンコード済みの絶対パス>
```

例:
```
aidea://open?path=%2FUsers%2Fme%2F.claude%2Fprojects%2Faidea%2Fabc123.jsonl
```

#### 動作

- Aidea がフォアグラウンドでなければ前面に出る
- `path` パラメータのファイルを Preview セッションで開く (既存の `openPreview` ルーティングに準拠)
- 同一 URL の Preview が既に存在する場合はアクティブ化 (dedupe)
- `path` パラメータが欠如・不正の場合は何もしない (エラー表示なし)

#### 実装ポイント

- `AideaApp.swift` の `WindowGroup` に `.onOpenURL { url in ... }` を追加
- URL スキームは `Info.plist` の `CFBundleURLTypes` で登録 (スキーム名: `aidea`)
- `file://` URL を直接受信した場合も同様に Preview で開く

#### Claude Code トランスクリプトの設定方法

Claude Code のトランスクリプトビューアから Aidea でファイルを開くには、次のシェルスクリプトを `$EDITOR` または Claude 設定の `editor` に設定する:

```bash
#!/bin/bash
# ~/.local/bin/aidea-open
open "aidea://open?path=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1")"
```

---

## 実装メモ

### 既存コード
- `PreviewSessionState.url: URL?` `title: String?` を保持
- `PreviewSessionView` が state.url の拡張子を見て SwiftUI 分岐

### drawio 実装コンポーネント
- `DrawioPreview` — View/Edit モード切替、保存/キャンセル UI
- `DrawioStaticView` — `.drawio.svg` の静的表示 / `.drawio` の chrome=0 レンダリング
- `DrawioEditor` — `embed.diagrams.net` embed mode の WKWebView ラッパ、postMessage プロトコル仲介

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
