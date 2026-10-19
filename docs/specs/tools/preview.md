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
last_updated: 2026-07-13
---

# Tool 仕様: Preview

ファイルを読み取り専用で表示する Tool。Kit や Filer から共通の Preview 起動経路で開かれる。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/preview.md](../sessions/preview.md) を参照。
共通 UI 規約は [sessions/ui-rules.md](../sessions/ui-rules.md) と [window/](../window/README.md) を参照。

---

## 概要

- Preview Session は 1 つのファイルを表示する
- ファイルの種別に応じて **コンテンツハンドラ**を切り替える (同じ Preview Session で複数の種別を透過的に扱う)
- タブタイトルは呼び出し元が指定したタイトルがあればそれ、無ければ URL の最終要素
- Preview は Window 内に複数インスタンス同時存在可

## ファイル種別とコンテンツハンドラ

| 拡張子 / 条件 | ハンドラ | 状態 |
|---|---|---|
| `.md` / `.markdown` | Markdown プレビュー (外部依存なしの軽量パーサ) | 実装済 |
| `.png` `.jpg` `.jpeg` `.gif` `.heic` `.webp` `.bmp` | 画像表示 (ネイティブ画像ロード) | 実装済 |
| `.mp4` `.mov` `.m4v` `.mkv` `.avi` | 動画プレーヤー (AVKit) | 実装済 |
| `.drawio.svg` / `.drawio` | drawio プレビュー (後述) | 実装済 |
| テキスト全般 (バイナリ判定で NUL を含まない) | テキスト表示 (NSTextView ベース) | 実装済 |
| サイズ > 1MB | "ファイルが大きすぎます" メッセージ | 実装済 |
| バイナリ (NUL を含む) | "プレビュー非対応のバイナリ" メッセージ | 実装済 |

---

## 機能

### openFile — ファイルを開く
- 共通の Preview 起動経路から呼ばれる
- 表示対象 URL を更新すると、種別に応じたコンテンツハンドラが自動判定される
- 既存 Preview に同じ URL がある場合は新規作成せずアクティブ化 (起動経路側が dedupe する)
- 詳細は [sessions/active-session.md#preview-を開くときの呼び出し規約](../sessions/active-session.md#preview-を開くときの呼び出し規約) を参照

### renderMarkdown — Markdown を見やすく表示
- `.md` / `.markdown` を Markdown プレビューで表示
- 見出し (`# ~ ####`) / コードブロック / Mermaid 図 / 箇条書き / 水平線 / frontmatter / インライン (bold・italic・リンク・`code`) をサポート
- 外部依存なし (インライン装飾は SwiftUI ネイティブの Markdown 解釈に委譲)

#### runShellScript — シェルスクリプトコードブロックの実行

- view モードで表示中のシェルスクリプトコードブロック右上に `▶` 実行ボタンを表示する
- 対象言語: `bash` / `sh` / `zsh` / `shell` / `fish` / `ksh` / `csh` / `tcsh`
- 実行ボタン押下時の挙動:
  - 既存の Terminal セッションがあれば、そのタブをアクティブ化してコマンドを PTY へ送信する
  - Terminal セッションがなければ、新規 Terminal タブを作成してシェル起動後 (800ms 待機) にコマンドを送信する
- edit モード中は実行ボタンを表示しない (コードブロックはテキストとして編集する)

#### 見出し内インラインコード

- 見出し行 (`` # ~ #### ``) 内のバッククォートコードスパン (`` `code` ``) は等幅フォントで表示する
- 見出しの文字サイズ・ウェイトはそのままに、コードスパン部分のみ等幅デザインを適用する
- コードスパン部分には薄いグレー背景と角丸 (radius 3) を付与し、インラインコードブロックと視覚的に一貫したスタイルにする
- 目次 (ToC) 表示では、バッククォート記号を除いたプレーンテキストで表示する

#### frontmatter 表示

- フォント: 本文と同サイズのモノスペースフォント
- 背景: 薄いグレーのラウンドコーナーブロック
- YAML 行を `key: value` および配列項目 `  - value` の形式で行ごとに解析する
- **ファイルパスのクリック**: 値がローカルファイルパスと判定される場合 (`/` を含み `http` / `[` / `{` で始まらない) はリンクとして表示し、タップすると隣タブで Preview が開く
- パス解決順: ① ファイルの親ディレクトリからの相対パス → ② 親を順にさかのぼって最初に一致するパス (上限 10 段) → 見つからなければリンク非表示

#### Mermaid 図の表示

- Markdown 内の ` ```mermaid ... ``` ` ブロックを Mermaid 図として描画する
- **view モード**: WKWebView + CDN の Mermaid.js でレンダリング。描画完了後に高さを自動調整
- **edit モード**: 通常のコードブロックとして表示 (生テキスト)
- パース失敗時はエラーメッセージを赤文字で表示
- ネットワーク接続が必要 (drawio embed と同様、オフライン対応は将来検討)

#### view / edit モード切替 UI

Markdown は **view / edit の 2 モード**を持つ。右上にフローティングで **アイコンのみのセグメントコントロール** を配置し、ユーザーはワンタップで切り替えられる。

| モード | SF Symbols | 意味 |
|---|---|---|
| **view** | `eye` | プレビュー表示 |
| **edit** | `chevron.left.forwardslash.chevron.right` | 編集 (NSTextView ベースのエディタ) |

- **表示形式**: セグメントコントロール。ラベルはアイコンのみ (テキストなし)
- **操作**: セグメントタップで即座にモード切替。edit → view に戻すときは、未保存の編集テキストを **切替直前に flush 保存** してから view に遷移する (500ms デバウンスの自動保存と同じ経路)
- **配置**: 既存の右上フローティング位置 (padding top 10 / trailing 22) を維持
- **キーボード**: view モードで `E` を押すと edit に切替 (セグメントボタンと等価)。既存仕様維持
- **翻訳「日本語」ボタン**: 従来どおりセグメントコントロールの下に配置される (view モードかつ英語判定かつ翻訳キャッシュファイルでないときに表示)

#### 編集中のテキスト保護 (issue #125)

edit モードのエディタは、外部要因の再描画から編集中のテキストを保護する。

- **IME 未確定文字列の保護**: 日本語入力の変換中は、外部要因の再描画 (500ms 自動保存による状態更新など) が起きても未確定文字列を破棄しない
- **巻き戻し防止**: 連続入力中に、古い描画サイクルの値でエディタ内容を巻き戻さない
- **未確定文字列は保存しない**: 変換中のテキストは自動保存に乗らない。確定・取消時に確定分だけが保存対象になる

**Never**: IME 変換中にエディタのテキストを外部から書き換えない。

#### キャッシュファイル (`.aidea/ja/`) の扱い

`.aidea/ja/` 配下の翻訳キャッシュファイルはユーザーの編集対象外のため、**セグメントコントロールは表示しない**。代わりに「英語」ボタン (SF Symbols `character.book.closed`) のみを表示し、押すと元の英語ファイルを新しい Preview タブで開く。

### translateToJapanese — 英語ドキュメントの日本語翻訳

英語の Markdown / テキストファイルを Claude API で日本語に翻訳し、`.aidea/ja/` にキャッシュする。

#### フロー

1. 言語判定 (`LanguageDetector.isEnglish`、先頭 1000 文字を `NLLanguageRecognizer` でサンプル) が英語と判定 → 右上に「日本語」ボタンを表示
2. ボタン押下 → 翻訳処理がキャッシュの有無と鮮度 (mtime 比較) を確認
3. キャッシュが新鮮ならそのまま表示。古い or 無ければ Claude API で SSE ストリーミング翻訳
4. Claude API の `claude-haiku-4-5-20251001` に `stream: true` でリクエスト送信 (Markdown 構造・コード識別子は保持)
5. チャンク受信のたびに `.aidea/ja/<相対パス>/<filename>` へ累積テキストを書き込む
6. 最初のチャンク受信時に翻訳版の Preview タブを開く → ファイル監視 (FSEvents) がその後の書き込みを検知して表示を逐次更新
7. 翻訳完了 (ストリーム終端) 後にボタン状態を完了に更新する

#### 言語判定の代表ケース (issue #287)

`NLLanguageRecognizer` の `dominantLanguage` に依存する判定のため、代表的な入力での挙動を明文化する
(`LanguageDetectorTests` で固定)。

| 入力 | 判定 |
|---|---|
| 英文のみ | 英語 (ボタン表示) |
| 日本語のみ | 非英語 |
| 空文字列 | 非英語 |
| 英語の説明文にコードブロックが混じる (英語が主体) | 英語 |
| 日本語の説明文に英単語が少し混じる (日本語が主体) | 非英語 |
| 記号・数字だけ | 非英語 (判定不能ケースは非英語扱いにフォールバックする) |

#### ストリーミング (SSE)

- 行単位に SSE イベントをストリーミング受信する (タイムアウト不要)
- `data: {...}` 行のみ処理し、`type == "content_block_delta"` かつ `delta.type == "text_delta"` の `delta.text` を取り出す
- エラー終了時はキャッシュファイルを削除して不完全なキャッシュを残さない

#### 進捗 UI

- 翻訳中はボタンラベルを「翻訳中... (N 文字)」に更新する (N = 累積受信文字数)
- 最初のチャンク受信前は「翻訳中...」のみ表示

#### API キー設定

- Anthropic API キーを **macOS Keychain** に保存 (サービス: `com.aidea.anthropic-api-key`)
- 初回翻訳時またはメニュー「Aidea → API キー設定...」でセキュアテキスト入力ダイアログを表示

#### UI 表示箇所

- Markdown 表示時: 右上フローティングの「日本語」ボタン
- テキストファイル表示時: 翻訳ボタン

### manualReload — 右クリックからの手動リロード (issue #241)

右クリックメニューの「リロード」で、表示中のファイルをディスクから明示的に再読み込みする。
自動リロード (FSEvents) が効かないケース (動画 / drawio の取りこぼし等) や、ユーザが任意に更新したいときの手段。

- リロード要求を発行すると、各プレビュー子ビューがそれを観測して再読み込みする (全コンテンツ種別: テキスト / 画像 / Markdown / Drawio / 動画)
- Markdown / Drawio が **edit モードのときは無視**する (未保存の編集を破棄しないため。自動リロードと同じ方針)
- 対象は表示対象ファイル (url) を持つ Preview タブのみ (メニュー自体が Preview タブにしか出ない)

### autoReload — 外部変更の自動再読み込み

プレビュー表示中のファイルが外部 (Claude など) によって変更されたとき、プレビュー表示を自動的に更新する。

- ファイルの変更は **FSEvents** で検知する
- 監視パス・比較対象はシンボリックリンクを解決した実パスに揃える。FSEvents はシンボリックリンクを
  解決した実パスで変更を通知するため、揃えないとリンク経由で開いたファイル (issue #119) の変更が
  検知できない (issue #254)
- 変更を検知したら直ちにファイルを再読み込みしてプレビューを更新する
- **編集モード中は更新しない**: Markdown / drawio が edit モードのときはスキップし、view モードに戻ったタイミングで反映される
- 対象: Markdown / drawio の **view モード**、およびテキスト / 画像ファイル
- drawio は **view モードのみ**自動リロードする。edit モード (embed.diagrams.net エディタ) は未保存の外部状態を持つため対象外 (Markdown の view/edit と同じ作法)
- 動画は自動リロード対象外 (手動リロードのみ)

### tabHoverTooltip — タブホバー時のパス表示

Preview タブにマウスカーソルを合わせると、ツールチップでファイルのパスを表示する。

- projectRoot が設定されており表示対象ファイルがその配下にある場合: プロジェクトルートからの相対パスを表示 (例: `docs/specs/tools/preview.md`)
- 表示対象ファイルが projectRoot 配下にない場合、または projectRoot 未設定の場合: 絶対パスを表示
- 表示対象ファイルが無い場合: ツールチップなし

### タブ右クリックメニュー (issue #238)

Preview タブを右クリックすると、コンテキストメニューを表示する。対象は表示対象ファイル (url) を持つ Preview タブのみで、
url が無いタブ・Preview 以外のタブにはメニューを出さない (空メニューを表示しない)。共通の右クリック規約は
[sessions/ui-rules.md#右クリックコンテキストメニュー](../sessions/ui-rules.md#右クリックコンテキストメニュー) に従う。

| 項目 | 動作 |
|---|---|
| タブ名を変更 | タブのインラインリネームを開始する (タブのダブルクリックと同じ) |
| リロード | 表示中のファイルをディスクから再読み込みする ([manualReload](#manualreload--右クリックからの手動リロード-issue-241)) |
| ファイル名をコピー | ファイル名 (URL の最終要素) をクリップボードにコピー |
| プロジェクト相対パスをコピー | projectRoot 相対パス (ツールチップと同じ算出) をコピー。projectRoot 外/未設定なら絶対パス |
| 絶対パスをコピー | 正規化した絶対パスをコピー |
| ファイラで選択 | Filer セッションで当該ファイルを選択し、**スクロール位置を中央に寄せて** フォーカスする |
| タブを閉じる | このタブを閉じる (× ボタンと同じ) |

- クリップボードへは文字列としてコピーする (既存内容をクリアしてから書き込む)
- 「ファイラで選択」は Filer の外部エントリポイント ([tools/filer.md#revealinfiler--外部からのファイル選択-issue-238](./filer.md#revealinfiler--外部からのファイル選択-issue-238)) を呼ぶ。
  親ディレクトリを展開して対象行を選択し、「見える位置まで」ではなく**中央寄せスクロール**で表示する。
  Filer セッションが存在しない場合は何もしない

### renderImage — 画像表示
- 対応拡張子をネイティブ画像としてロードし、スクロール可能なビューで表示

### renderVideo — 動画再生

`.mp4` / `.mov` / `.m4v` / `.mkv` / `.avi` を AVKit のネイティブプレーヤーで表示する。

- 再生・停止・シークバー・音量などの標準コントロールを表示する
- ファイルを開いた時点で再生を開始しない (ユーザーが再生ボタンを押してから再生)
- タブを切り替えるなどビューが非表示になったとき、再生を自動停止する
- 動画ファイルはサイズ制限 (1 MB) および バイナリ判定を適用しない (ファイルは直接プレーヤーへ渡す)

### renderDrawio — drawio 図の表示・編集

drawio ファイル (`.drawio.svg` / `.drawio`) を **プレビューと編集の 2 モード**で扱う。
Obsidian の drawio プラグインと同等の UX を目指す。

#### プレビューモード (初期表示)
- `.drawio.svg` の場合: SVG 部分をネイティブ画像として表示 (drawio ファイルはそのまま有効な SVG)
- `.drawio` の場合: XML のみなので SVG 表現がない → **初回は WKWebView で drawio エディタを隠れた状態で動かして SVG を export** してキャッシュ表示
  (MVP では `.drawio` サポートは後回し、まず `.drawio.svg` を優先)
- 右上に **`✎ Edit` ボタン**

#### 編集モード (Edit ボタン押下)
- WKWebView に **`https://embed.diagrams.net/?embed=1&ui=dark&spin=1&proto=json`** をロード
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
- `path` パラメータのファイルを Preview セッションで開く (既存の Preview 起動経路のルーティングに準拠)
- 同一 URL の Preview が既に存在する場合はアクティブ化 (dedupe)
- `path` パラメータが欠如・不正の場合は何もしない (エラー表示なし)
- URL スキームは `Info.plist` の `CFBundleURLTypes` で登録する (スキーム名: `aidea`)
- `file://` URL を直接受信した場合も同様に Preview で開く

#### Claude Code トランスクリプトの設定方法

Claude Code のトランスクリプトビューアから Aidea でファイルを開くには、次のシェルスクリプトを `$EDITOR` または Claude 設定の `editor` に設定する:

```bash
#!/bin/bash
# ~/.local/bin/aidea-open
open "aidea://open?path=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1")"
```

---

## 依存

- **外部依存追加なし** (embed.diagrams.net / Mermaid.js はオンライン CDN で使用、WebKit は既に使用中)
- オフライン対応は将来検討

---

## 未検討事項 (将来)

- `.drawio` (純 XML) のプレビュー (初回 SVG 生成ロジック)
- 新規 drawio ファイル作成 (Filer の Cmd+N からテンプレート生成)
- オフライン対応 (drawio HTML/JS を Aidea にバンドル)
- ダーク/ライトテーマ同期 (現状は `ui=dark` 固定)
- 複数ページ drawio の扱い
- 画像 (png/jpg) の編集 (drawio は対応しない)
