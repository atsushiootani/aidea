---
title: "Tool 仕様: Web"
description: WKWebView ベースの Web ブラウザ Tool 仕様 (ナビゲーションツールバー / URL クリックルーティング)
derived_from:
  - docs/decisions/0015-wkwebview-scope-and-chrome-coexistence.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/window/
syncs_with:
  - docs/specs/sessions/web.md
  - docs/specs/tools/terminal.md
  - docs/specs/aspects/keybindings.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-20
---

# Tool 仕様: Web

WKWebView ベースの内蔵ブラウザ Tool。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/web.md](../sessions/web.md) を参照。
WKWebView の制約と Chrome 併用方針は [ADR 0015](../../decisions/0015-wkwebview-scope-and-chrome-coexistence.md) を参照。
`window.open` / `target="_blank"` の扱いは [ADR 0035](../../decisions/0035-web-window-open-tab-and-popup.md) を参照。

## ナビゲーションツールバー

WebSessionView の上部に、一般的なブラウザと同じ並びでツールバーを表示する。

```
[←] [→] [⟳] [ URL 欄                          ] [🌐] [🔍]
```

| 要素 | 動作 | 備考 |
|---|---|---|
| 戻る (←) | `webView.goBack()` | `canGoBack == false` のとき disabled (KVO 追従) |
| 進む (→) | `webView.goForward()` | `canGoForward == false` のとき disabled (KVO 追従) |
| 更新 (⟳) | `webView.reload()` | |
| URL 欄 | 現在の URL を表示。**編集可能**: Enter 押下でその URL へ移動 | ナビゲーションには既存の `url` KVO で追従。編集中 (フォーカス中) はユーザ入力を追従更新で上書きしない |
| 地球アイコン (🌐) | 現在の URL を `NSWorkspace.shared.open` で **OS デフォルトブラウザ** に開く | ADR 0015 の「Chrome 併用」への導線 |
| 検索アイコン (🔍) | ツールバー下の **ページ内検索バー** をトグルする | 開いている間はアクセントカラーで点灯。後述の[ページ内検索](#ページ内検索)を参照 |

### URL 欄の入力解釈

- scheme なしの入力 (例: `example.com`) は `https://` を補完する
- URL として解釈できない入力は無視する (移動しない)

### 実装方式 (ネイティブコンポーネント検討の結果)

ツールバーは **SwiftUI 自作** (HStack + TextField + SF Symbols) とする。検討した代替案:

| 候補 | 不採用理由 |
|---|---|
| `NSToolbar` / SwiftUI `.toolbar` | ウィンドウ単位にしか付かず、ペイン内に複数 Web セッションを持つ構造に合わない |
| `SFSafariViewController` | iOS 専用 API で macOS に存在しない |
| SwiftUI `WebView` (WebKit for SwiftUI) | macOS 26+ 限定 (最低ターゲット macOS 15)。ナビゲーションバーも提供しない |

部品レベルでは標準を使う (SF Symbols: `chevron.left` / `chevron.right` / `arrow.clockwise` / `globe` / `magnifyingglass`)。

## ページ内検索

ツールバーの検索アイコン (🔍) を押すと、ツールバーと WKWebView の間に検索バーが開く。
表示中ページのテキストを WKWebView の `find(_:configuration:completionHandler:)` API で検索する。

```
[🔍] [ 検索語                         ] [見つかりません] [↑] [↓] [✕]
```

| 要素 | 動作 |
|---|---|
| 検索フィールド | 入力するたびに (`onChange`) 前方検索を実行し、最初のヒットへスクロール＆ハイライト |
| 前を検索 (↑) | 後方検索 (`forward: false`)。検索語が空のとき disabled |
| 次を検索 (↓) | 前方検索。検索フィールドで Enter を押しても同じ |
| 閉じる (✕) | 検索バーを閉じ、検索語をクリアする。**Esc キー**でも閉じる |
| 「見つかりません」 | 検索語が非空でヒット 0 件のとき赤字で表示 |

- 検索設定 (`WKFindConfiguration`) は **大文字小文字を無視** (`caseSensitive = false`)、**末尾で先頭に折り返す** (`wraps = true`)
- 検索ロジックは `WebSessionState.find(_:forward:completion:)` に置き、View 側は表示と入力ハンドリングのみ担う (URL ロードを `loadURLString` に置くのと同じ分担)
- 検索バーを開くと検索フィールドへ自動フォーカスする

## タブ名

Web セッションのタブヘッダには **現在の URL** を表示する (`PaneView.displayLabel(for:)`)。

- 先頭の `https://` / `http://` は除去する
- 除去後の **先頭 20 文字だけ** を表示する (長い URL でタブが伸びすぎないため)
- ナビゲーションに追従して更新する (`WebSessionState.url` の変更に追従)

例: `https://github.com/atsushiootani/aidea/pull/223` → `github.com/atsushioo`

## URL クリックルーティング (Terminal / Claude → Web)

Terminal / Claude セッションのターミナル出力中の URL をクリックしたとき、
外部ブラウザではなく **Web Tool で開く**。

- 対象 scheme は **http / https のみ**。それ以外 (`mailto:` 等) は従来通り `NSWorkspace.shared.open`
- 配置先は **「呼び出し元 (カレント) ペインを除く最新のペイン」**:
  `activeSessionHistory` を新しい順に走査し、呼び出し元ペイン以外で最初に見つかった
  セッションが属するペインを選ぶ。見つからなければ呼び出し元以外の先頭ペイン
  (Preview の `openPreview` と同一アルゴリズム。[sessions/active-session.md](../sessions/active-session.md) 参照)
- **常に新規 Web タブを作成** する (既存 Web セッションの再利用・dedupe はしない)
- 作成した Web タブをアクティブ化する

エントリポイントは `SessionRegistry.openWeb(for:)`。
Terminal 側のクリック判定は [tools/terminal.md#url-クリック](./terminal.md#url-クリック) を参照。

## window.open / target="_blank" のルーティング ([ADR 0035](../../decisions/0035-web-window-open-tab-and-popup.md))

ページ内の `window.open()` や `target="_blank"` のリンクは、`WKUIDelegate` で受け取り、
**windowFeatures のサイズ指定有無**で出し先を振り分ける。

| 起点 | 条件 | 出し先 |
|---|---|---|
| `window.open(url, name, "width=..,height=..")` | windowFeatures に width か height がある | **フローティングポップアップ窓** |
| `target="_blank"` リンク / `window.open(url)` | windowFeatures にサイズ指定がない | **新規 Web タブ** (呼び出し元と同じペインの右隣) |

### 共通ルール

- WebKit から渡された **`configuration` をそのまま使って**子 WKWebView を生成する
  (opener との `window.opener` / `postMessage` / `window.close()` を成立させるため)
- 子 WKWebView を**自前で `load` しない** (WebKit が `navigationAction` を自動ロードする)
- 子 WKWebView にも `uiDelegate` を設定し、入れ子の `window.open` を再帰的に扱う
- 生成元 WKWebView の `WebSessionState` を opener として、その隣 (新規タブ時) / 独立窓 (ポップアップ時) に出す

### 新規 Web タブ (サイズ指定なし)

- 渡された子 WKWebView を **adopt** した `WebSessionState` を新規 Web セッションとして作る
  (自前生成・初期ロードはしない。`sessions/web.md#子-webview-の-adopt` を参照)
- 配置は **呼び出し元 (opener) と同じペインの右隣** に挿入してアクティブ化する
  (`SessionRegistry.openWebAdopting(_:from:)`)
- これは URL クリックルーティング (`openWeb`、別ペインへ出す) とは別ポリシー。
  ページ内リンクは「同じブラウジング文脈の続き」なので隣に出す

### フローティングポップアップ窓 (サイズ指定あり)

- 独立した `NSWindow` (`.titled` / `.closable` / `.resizable`) に子 WKWebView をホストする
- registry が窓のコントローラを生存参照として保持し、`webViewDidClose` (= `window.close()`) または
  ユーザの窓クローズで解放する
- 窓は妥当な既定サイズで出す (windowFeatures の位置・サイズの厳密な再現はしない。
  サイズ指定は「ポップアップとして扱うか」の判定にのみ使う)

## JavaScript ダイアログ (alert / confirm / prompt)

ページ内の `window.alert()` / `window.confirm()` / `window.prompt()` を `WKUIDelegate` で受け取り、
ネイティブの `NSAlert` として表示する。`WKUIDelegate` がこれらのメソッドを実装しないと WebKit は
JS ダイアログを**黙って握り潰す** (何も表示されず `confirm` は `false`・`prompt` は `null` 相当を返す)
ため、確認ダイアログ付きの操作 (例: promote ボタンの `confirm()`) が無反応になる。

| JS API | WKUIDelegate メソッド | 表示 | 返す値 |
|---|---|---|---|
| `alert(msg)` | `runJavaScriptAlertPanel...` | メッセージ + 「OK」 | (なし。閉じたら `completionHandler()`) |
| `confirm(msg)` | `runJavaScriptConfirmPanel...` | メッセージ + 「OK」/「キャンセル」 | OK=`true` / キャンセル=`false` |
| `prompt(msg, default)` | `runJavaScriptTextInputPanel...` | メッセージ + テキスト入力欄 + 「OK」/「キャンセル」 | OK=入力文字列 / キャンセル=`null` |

### 共通ルール

- `NSAlert` は WKWebView が乗っている**ウィンドウのシート**として表示する (`beginSheetModal(for:)`)。
  そのウィンドウだけをブロックし、他ウィンドウ・他ペインの操作は妨げない
- WKWebView にウィンドウがない稀なケース (生成直後など) は `runModal()` にフォールバックする
- ダイアログのタイトル (`messageText`) には**発信元ページのホスト**を表示し (例: `localhost:3000`)、
  JS が渡したメッセージ本文は `informativeText` に表示する (ブラウザの「〜 says:」慣習に倣う)。
  ホストが取得できない場合は「このページ」と表示する
- ボタンのラベルは日本語 (「OK」「キャンセル」)。confirm/prompt の既定ボタンは「OK」
- `completionHandler` は**必ず一度だけ**呼ぶ (WebKit の契約。呼ばないと当該ページの JS が停止する)
- 表示ロジックは通常タブ (`WebUIDelegate`) とポップアップ窓 (`WebPopupController`) で**共有**する
  (`WebJavaScriptDialog` ヘルパに集約)

## 境界

### Always
- ツールバーのボタン有効状態 (`canGoBack` / `canGoForward`) は WKWebView の KVO に追従する
- URL クリックルーティングは http / https のみを対象とする
- `window.open` / `target="_blank"` は WebKit から渡された `configuration` で子 WKWebView を作り、自前 load しない
- 新規 Web タブは opener と同じペインの右隣に出す / ポップアップ窓は `webViewDidClose` で閉じる
- JS の alert / confirm / prompt は `NSAlert` シートで表示し、`completionHandler` を必ず一度呼ぶ

### Never
- 既存 Web セッションへの URL ロード (再利用) は行わない — 常に新規タブ
- 呼び出し元 (カレント) ペインには (URL クリックルーティングでは) Web タブを作らない
- 子 WKWebView を自前で生成・ロードしない (opener 関係が切れて OAuth が壊れるため)
- JS ダイアログを握り潰さない (WKUIDelegate 未実装のまま放置しない)
