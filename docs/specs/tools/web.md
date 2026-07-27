---
title: "Tool 仕様: Web"
description: WKWebView ベースの Web ブラウザ Tool 仕様 (ナビゲーションツールバー / URL クリックルーティング)
derived_from:
  - docs/decisions/0015-wkwebview-scope-and-chrome-coexistence.md
  - docs/decisions/0041-open-in-chrome-matched-size.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/window/
syncs_with:
  - docs/specs/sessions/web.md
  - docs/specs/tools/terminal.md
  - docs/specs/aspects/keybindings.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-27
---

# Tool 仕様: Web

WKWebView ベースの内蔵ブラウザ Tool。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/web.md](../sessions/web.md) を参照。
WKWebView の制約と Chrome 併用方針は [ADR 0015](../../decisions/0015-wkwebview-scope-and-chrome-coexistence.md) を参照。
`window.open` / `target="_blank"` の扱いは [ADR 0035](../../decisions/0035-web-window-open-tab-and-popup.md) を参照。
地球アイコンの ⌘クリックで Chrome を同じ位置・サイズで開く挙動は [ADR 0041](../../decisions/0041-open-in-chrome-matched-size.md) を参照。

## ナビゲーションツールバー

ページ表示領域の上部に、一般的なブラウザと同じ並びでツールバーを表示する。

```
[←] [→] [⟳] [ URL 欄                          ] [🌐] [🔍]
```

| 要素 | 動作 | 備考 |
|---|---|---|
| 戻る (←) | 1 つ前のページへ戻る | 戻れないとき disabled (履歴状態に追従) |
| 進む (→) | 1 つ先のページへ進む | 進めないとき disabled (履歴状態に追従) |
| 更新 (⟳) | 現在のページを再読み込みする | |
| URL 欄 | 現在の URL を表示。**編集可能**: Enter 押下でその URL へ移動 | ページ遷移に追従。編集中 (フォーカス中) はユーザ入力を追従更新で上書きしない |
| 地球アイコン (🌐) | 現在の URL を **OS デフォルトブラウザ** で開く。**⌘クリック**すると現在の Web タブと同じ位置・サイズの Chrome ウィンドウで開く | ADR 0015 の「Chrome 併用」への導線。⌘クリックの詳細は [ADR 0041](../../decisions/0041-open-in-chrome-matched-size.md) と後述の[Chrome を同じ位置・サイズで開く](#chrome-を同じ位置サイズで開く-⌘クリック)を参照 |
| 検索アイコン (🔍) | ツールバー下の **ページ内検索バー** をトグルする | 開いている間はアクセントカラーで点灯。後述の[ページ内検索](#ページ内検索)を参照 |

### URL 欄の入力解釈

- scheme なしの入力 (例: `example.com`) は `https://` を補完する
- URL として解釈できない入力は無視する (移動しない)

### 実装方式 (ネイティブコンポーネント検討の結果)

ツールバーは **SwiftUI で自作**する。検討した代替案と不採用理由:

| 候補 | 不採用理由 |
|---|---|
| ウィンドウ標準ツールバー | ウィンドウ単位にしか付かず、ペイン内に複数 Web セッションを持つ構造に合わない |
| Safari ビューコントローラ | iOS 専用で macOS に存在しない |
| WebKit for SwiftUI の WebView | macOS 26+ 限定 (最低ターゲット macOS 15)。ナビゲーションバーも提供しない |

アイコンは SF Symbols を使う (戻る / 進む / 更新 / 地球 / 虫めがね)。

## ページ内検索

ツールバーの検索アイコン (🔍) を押すと、ツールバーとページの間に検索バーが開く。
表示中ページのテキストを WebView 標準の検索機能で検索する。

```
[🔍] [ 検索語                         ] [見つかりません] [↑] [↓] [✕]
```

| 要素 | 動作 |
|---|---|
| 検索フィールド | 入力するたびに前方検索を実行し、最初のヒットへスクロール＆ハイライト |
| 前を検索 (↑) | 後方検索。検索語が空のとき disabled |
| 次を検索 (↓) | 前方検索。検索フィールドで Enter を押しても同じ |
| 閉じる (✕) | 検索バーを閉じ、検索語をクリアする。**Esc キー**でも閉じる |
| 「見つかりません」 | 検索語が非空でヒット 0 件のとき赤字で表示 |

- 検索は **大文字小文字を無視**し、**末尾で先頭に折り返す**
- 検索ロジックは Web セッション状態側に置き、View は表示と入力ハンドリングのみを担う (URL ロードと同じ分担)
- 検索バーを開くと検索フィールドへ自動フォーカスする

## タブ名

Web セッションのタブヘッダには **現在の URL** を表示する。

- 先頭の `https://` / `http://` は除去する
- 除去後の **先頭 20 文字だけ** を表示する (長い URL でタブが伸びすぎないため)
- ページ遷移に追従して更新する

例: `https://github.com/atsushiootani/aidea/pull/223` → `github.com/atsushioo`

## URL クリックルーティング (Terminal / Claude → Web)

Terminal / Claude セッションのターミナル出力中の URL をクリックしたとき、
外部ブラウザではなく **Web Tool で開く**。

- 対象 scheme は **http / https のみ**。それ以外 (`mailto:` 等) は従来通り OS デフォルトアプリで開く
- 配置先は **「呼び出し元 (カレント) ペインを除く最新のペイン」**:
  アクティブ履歴を新しい順に走査し、呼び出し元ペイン以外で最初に見つかった
  セッションが属するペインを選ぶ。見つからなければ呼び出し元以外の先頭ペイン
  (履歴ベースの配置。Preview は issue #275 で右端ペイン固定に変わったが、Web タブは従来どおりこの方式)
- **常に新規 Web タブを作成** する (既存 Web セッションの再利用・dedupe はしない)
- 作成した Web タブをアクティブ化する

Terminal 側のクリック判定は [tools/terminal.md#url-クリック](./terminal.md#url-クリック) を参照。

## window.open / target="_blank" のルーティング ([ADR 0035](../../decisions/0035-web-window-open-tab-and-popup.md))

ページ内の `window.open()` や `target="_blank"` のリンクは UI デリゲートで受け取り、
**windowFeatures のサイズ指定有無**で出し先を振り分ける。

| 起点 | 条件 | 出し先 |
|---|---|---|
| `window.open(url, name, "width=..,height=..")` | サイズ指定 (width か height) がある | **フローティングポップアップ窓** |
| `target="_blank"` リンク / `window.open(url)` | サイズ指定がない | **新規 Web タブ** (呼び出し元と同じペインの右隣) |

### 共通ルール

- WebKit から渡された **設定をそのまま使って**子 WebView を生成する
  (opener との `window.opener` / `postMessage` / `window.close()` を成立させるため)
- 子 WebView を**自前でロードしない** (WebKit がリンク先を自動で読み込む)
- 子 WebView にも UI デリゲートを設定し、入れ子の `window.open` を再帰的に扱う
- 生成元の Web セッションを opener として、その隣 (新規タブ時) / 独立窓 (ポップアップ時) に出す

### 新規 Web タブ (サイズ指定なし)

- 渡された子 WebView を **引き取った** (adopt した) Web セッションを新規に作る
  (自前生成・初期ロードはしない。`sessions/web.md#子-webview-の-adopt` を参照)
- 配置は **呼び出し元 (opener) と同じペインの右隣** に挿入してアクティブ化する
- これは URL クリックルーティング (別ペインへ出す) とは別ポリシー。
  ページ内リンクは「同じブラウジング文脈の続き」なので隣に出す

### フローティングポップアップ窓 (サイズ指定あり)

- 独立したウィンドウ (タイトルバー・クローズ・リサイズ可) に子 WebView をホストする
- 窓のコントローラを生存参照として保持し、JS の `window.close()` またはユーザの窓クローズで解放する
- 窓は妥当な既定サイズで出す (位置・サイズの厳密な再現はしない。
  サイズ指定は「ポップアップとして扱うか」の判定にのみ使う)

## Chrome を同じ位置・サイズで開く (⌘クリック) ([ADR 0041](../../decisions/0041-open-in-chrome-matched-size.md))

WKWebView (Safari 相当) が非対応と判定するサイトに遭遇したとき、Web タブを離れた感覚を
出さずに Chrome へ切り替えられるようにする導線。

- ツールバーの地球アイコンを **⌘クリック**すると、現在の Web タブの表示領域と**同じ位置・
  サイズ**の新規 Chrome ウィンドウを開き、同じ URL を読み込む
- Cmd を押さない単純クリックは従来通り OS デフォルトブラウザで開く (挙動を変えない)
- 位置・サイズは呼び出し時点の Web タブ (WKWebView) の画面上の frame から算出する
- 常に**新規 Chrome ウィンドウ**を開く (既存 Chrome ウィンドウの再利用・リサイズはしない)

### フォールバック

以下のいずれかに該当する場合、⌘クリックでも**単純クリックと同じ OS デフォルトブラウザ**へ
フォールバックする (エラー表示はしない)。

- Google Chrome がインストールされていない
- Web タブがまだ画面に描画されておらず、表示領域の frame が取得できない

## JavaScript ダイアログ (alert / confirm / prompt)

ページ内の `window.alert()` / `window.confirm()` / `window.prompt()` を UI デリゲートで受け取り、
ネイティブのアラートとして表示する。UI デリゲートがこれらを扱わないと WebKit は
JS ダイアログを**黙って握り潰す** (何も表示されず `confirm` は `false`・`prompt` は `null` 相当を返す)
ため、確認ダイアログ付きの操作 (例: promote ボタンの `confirm()`) が無反応になる。

| JS API | 表示 | 返す値 |
|---|---|---|
| `alert(msg)` | メッセージ + 「OK」 | (なし。閉じたら制御を返す) |
| `confirm(msg)` | メッセージ + 「OK」/「キャンセル」 | OK=`true` / キャンセル=`false` |
| `prompt(msg, default)` | メッセージ + テキスト入力欄 + 「OK」/「キャンセル」 | OK=入力文字列 / キャンセル=`null` |

### 共通ルール

- アラートは WebView が乗っている**ウィンドウのシート**として表示する。
  そのウィンドウだけをブロックし、他ウィンドウ・他ペインの操作は妨げない
- WebView にウィンドウがない稀なケース (生成直後など) はアプリモーダル表示にフォールバックする
- ダイアログのタイトルには**発信元ページのホスト**を表示し (例: `localhost:3000`)、
  JS が渡したメッセージ本文をその下に表示する (ブラウザの「〜 says:」慣習に倣う)。
  ホストが取得できない場合は「このページ」と表示する
- ボタンのラベルは日本語 (「OK」「キャンセル」)。confirm/prompt の既定ボタンは「OK」
- ダイアログを閉じたら**必ず一度だけ WebKit に結果を返す** (返さないと当該ページの JS が停止する)
- 表示ロジックは通常タブと**ポップアップ窓の両方で共有**する

## 境界

### Always
- ツールバーのボタン有効状態 (戻れる / 進める) はページ履歴に追従する
- URL クリックルーティングは http / https のみを対象とする
- 地球アイコンの単純クリックは OS デフォルトブラウザで開く。⌘クリックは Chrome 未インストール
  または frame 取得不可のとき単純クリックと同じ挙動にフォールバックする
- `window.open` / `target="_blank"` は WebKit から渡された設定で子 WebView を作り、自前ロードしない
- 新規 Web タブは opener と同じペインの右隣に出す / ポップアップ窓は `window.close()` で閉じる
- JS の alert / confirm / prompt はネイティブのアラート (シート) で表示し、必ず一度だけ結果を返す

### Never
- 既存 Web セッションへの URL ロード (再利用) は行わない — 常に新規タブ
- 呼び出し元 (カレント) ペインには (URL クリックルーティングでは) Web タブを作らない
- 子 WebView を自前で生成・ロードしない (opener 関係が切れて OAuth が壊れるため)
- JS ダイアログを握り潰さない (UI デリゲート未対応のまま放置しない)
- ⌘クリックで既存 Chrome ウィンドウを再利用・リサイズしない — 常に新規ウィンドウ
