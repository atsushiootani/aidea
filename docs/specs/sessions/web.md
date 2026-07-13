---
title: Session 内部状態: Web
description: Web セッションが保持する状態 (現在 URL / WebView) とペイン移動での DOM 維持・永続化・Scene とレコメンドプロンプト・window.open の UI デリゲート
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/decisions/0015-wkwebview-scope-and-chrome-coexistence.md
  - docs/decisions/0035-web-window-open-tab-and-popup.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/web.md
  - docs/specs/aspects/persistence.md
  - docs/specs/companions/recommend-mode.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-10
---

# Session 内部状態: Web

`web` Tool の Session が保持する状態。
**ペイン移動で WebView の状態 (ページ・Cookie・スクロール位置) が失われない** ことを保証する。

共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| 状態 | 用途 | ペイン移動で保持 |
|---|---|---|
| 現在の URL | 表示中の URL (初期値: `https://www.apple.com`) | ✅ |
| WebView | 遅延生成した WebView 本体。開発者ツールを有効にする | ✅ |
| 戻れる / 進める | ツールバーの戻る / 進むボタンの有効状態。ページ履歴の変化に追従する | ✅ |
| セッション ID | 自身の識別子 (逆参照用) | ✅ |

ナビゲーションツールバー (戻る / 進む / 更新 / URL 欄 / 地球アイコン) の仕様は
[../tools/web.md#ナビゲーションツールバー](../tools/web.md#ナビゲーションツールバー) を参照。

## ペイン移動で状態を失わない仕組み

Terminal と同様に、非アクティブなタブも View を生かしたまま隠す方式 (ペイン内で重ねて透明化)。
View が生存し続けるので **WebView の DOM・JavaScript 実行コンテキスト・メディア再生が中断されない**。

## WebContent プロセスの共有 (issue #263)

全 Web タブは単一の共有プロセスプールを使う。タブごとに専用プールを割り当てると
WebContent プロセスもタブ数に比例して生成され、Web タブが他ツールより重くなる要因になっていた。
プールを共有しても Cookie / データストアの分離方針
([ADR 0015](../../decisions/0015-wkwebview-scope-and-chrome-coexistence.md)) には影響しない
(データの分離はデータストアの責務で、プロセスプールの共有とは独立)。

## UI デリゲートと子 WebView ([ADR 0035](../../decisions/0035-web-window-open-tab-and-popup.md))

Web セッションは WebView の UI デリゲートを保持し、`window.open()` / `target="_blank"` を扱う。

- WebView の生成時、および後述の引き取り (adopt) 時の**両方**で UI デリゲートを設定する
  (状態変化の監視・クリック検知・UI デリゲート設定を共通の初期化処理に集約する)。
  クリック検知の仕組みと、タブ破棄時に必ず解放しなければならない理由は
  [conventions/implementations/focus.md#サブクラス不可能な-nsview-のクリック検知-クリックモニタ](../../conventions/implementations/focus.md#サブクラス不可能な-nsview-のクリック検知-クリックモニタ) を参照。
- UI デリゲートは `window.open` を windowFeatures のサイズ指定有無で振り分ける ([tools/web.md](../tools/web.md#windowopen--targetblank-のルーティング-adr-0035)):
  - サイズ指定あり → フローティングポップアップ窓を生成
  - サイズ指定なし → 新規 Web タブ (opener の隣) として引き取る
- どちらも WebKit から渡された設定で子 WebView を生成し、**自前ロードしない**。
- UI デリゲートは JS の alert / confirm / prompt も扱い、ネイティブのアラート (シート) で表示する。
  表示ロジックはポップアップ窓と共有する
  ([tools/web.md#javascript-ダイアログ-alert--confirm--prompt](../tools/web.md#javascript-ダイアログ-alert--confirm--prompt))。
  扱わないと WebKit がダイアログを握り潰し、`confirm` 付きの操作が無反応になる。

### 子 WebView の adopt

`window.open` 等で WebKit から渡された WebView を、新しい Web セッションが**自前生成せず引き取る**経路。

- 渡された WebView を自身の WebView として据え、監視・クリック検知・UI デリゲートを設定する。
  **初期ロードはしない** (WebKit がリンク先を自動で読み込むため)
- 引き取ったセッションの URL は子 WebView の URL 変化に追従して更新される (初期は about:blank の場合あり)
- 通常生成と引き取りの違いは「自分でロードするか」だけで、その他の設定は共通化する

## フローティングポップアップ窓

サイズ指定付き `window.open` (OAuth 等) は独立したウィンドウにホストする。

- 独立ウィンドウ (タイトルバー・クローズ・リサイズ可) に子 WebView を載せ、その UI デリゲートも兼ねる。
  JS の `window.close()` で窓を閉じ、ユーザの窓クローズで生存参照から外れる
- ポップアップ窓のコントローラは配列で生存参照として保持する (窓クローズで解放)
- ポップアップ窓の WebView も UI デリゲートを持つため、入れ子の `window.open` を再帰的に扱える

## 永続化

現在 URL は `<projectRoot>/.aidea/workspace.json` に保存される。詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。

## Scene とレコメンドプロンプト

セッション共通の仕組み ([../frontchannels/scene.md](../frontchannels/scene.md)) で、Cmd+Enter のレコメンド送信に対応する。

| Scene 識別子 | 場面 |
|---|---|
| `"web"` | Web ツール全体 (URL で分岐しない) |

- 初期プロンプトは空、既定の Companion は index 0。
- ユーザは Web ツール下部のプロンプト編集エリアから追加できる。
