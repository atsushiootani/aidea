---
title: Session 内部状態: Web
description: WebSessionState の状態 (url / WKWebView キャッシュ) と PaneView ZStack による DOM 維持・workspace.json 永続化・Scene とレコメンドプロンプト・window.open の UI デリゲート
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
last_updated: 2026-06-20
---

# Session 内部状態: Web

`web` Tool の Session は `WebSessionState` として状態を保持する。
**ペイン移動で WKWebView の状態 (ページ・Cookie・スクロール位置) が失われない** ことを保証する。

共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `url` | `URL` | 現在表示中の URL (初期値: `https://www.apple.com`) | ✅ |
| `cached` | `WKWebView?` (ObservationIgnored) | 遅延生成した WKWebView。`isInspectable = true` | ✅ |
| `urlObservation` | `NSKeyValueObservation?` (ObservationIgnored) | `WKWebView.url` の KVO | ✅ |
| `canGoBack` | `Bool` | 戻るボタンの有効状態 (`WKWebView.canGoBack` の KVO 追従) | ✅ |
| `canGoForward` | `Bool` | 進むボタンの有効状態 (`WKWebView.canGoForward` の KVO 追従) | ✅ |
| `sessionID` | `SessionID?` (ObservationIgnored) | 自身の ID (逆参照用) | ✅ |
| `webView` | `WKWebView` (computed) | `cached` の lazy アクセサ | — |

ナビゲーションツールバー (戻る / 進む / 更新 / URL 欄 / 地球アイコン) の仕様は
[../tools/web.md#ナビゲーションツールバー](../tools/web.md#ナビゲーションツールバー) を参照。

## ペイン移動で状態を失わない仕組み

Terminal と同様に `PaneView` の ZStack + `opacity(0)` 方式。NSView が生存し続けるので
**WKWebView の DOM・JavaScript 実行コンテキスト・メディア再生が中断されない**。

## UI デリゲートと子 WebView ([ADR 0035](../../decisions/0035-web-window-open-tab-and-popup.md))

`WebSessionState` は WKWebView の `uiDelegate` を保持し、`window.open()` / `target="_blank"` を扱う。

| 要素 | 役割 |
|---|---|
| `uiDelegate` (`WebUIDelegate`、ObservationIgnored・強参照) | `createWebViewWith` / `webViewDidClose` を実装。`uiDelegate` は WKWebView 側で weak 参照なので state が強参照で保持する |

- `webView` の lazy 生成時、および後述の adopt 時の**両方**で `uiDelegate` を設定する
  (`configureWebView(_:)` に共通設定 = KVO 登録・クリックモニタ・uiDelegate 設定を集約する)。
- `WebUIDelegate.createWebView` は windowFeatures のサイズ指定有無で振り分ける ([tools/web.md](../tools/web.md#windowopen--targetblank-のルーティング-adr-0035)):
  - サイズ指定あり → `SessionRegistry` 経由でフローティングポップアップ窓を生成
  - サイズ指定なし → `SessionRegistry.openWebAdopting(_:from:)` で新規 Web タブ
- どちらも WebKit から渡された `configuration` で子 WKWebView を生成し、**自前 load しない**。

### 子 WebView の adopt

`window.open` 等で WebKit から渡された WKWebView を、新しい `WebSessionState` が**自前生成せず引き取る**経路。

| メソッド | 振る舞い |
|---|---|
| `adopt(_ webView:)` | `cached` に渡された WKWebView をセットし、`configureWebView(_:)` で KVO・クリックモニタ・uiDelegate を設定する。**初期ロード (`load`) はしない** (WebKit が navigationAction を自動ロードするため) |

- adopt した state の `url` は子 WebView の `\.url` KVO で追従更新される (初期は about:blank の場合あり)。
- 通常生成 (lazy getter) と adopt の違いは「`load` を呼ぶか」だけで、その他の設定は共通化する。

## フローティングポップアップ窓

サイズ指定付き `window.open` (OAuth 等) は独立した `NSWindow` にホストする。

| 要素 | 役割 |
|---|---|
| `WebPopupController` (NSObject) | `NSWindow` (`.titled` / `.closable` / `.resizable`) + 子 WKWebView を保持し、その WKWebView の `uiDelegate` を兼ねる。`webViewDidClose` で窓を閉じ、`windowWillClose` で registry の保持から外れる |

- `SessionRegistry` が `WebPopupController` を配列で生存参照として保持する (窓クローズで解放)。
- ポップアップ窓の WKWebView も `uiDelegate` を持つため、入れ子の `window.open` を再帰的に扱える。

## 永続化

現在 URL は `<projectRoot>/.aidea/workspace.json` に保存される。詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `currentScene()` | 場面 |
|---|---|
| `"web"` | Web ツール全体 (URL で分岐しない) |

- 初期プロンプトは空配列 (`[]`)、`defaultCompanionIndex` は `0`。
- ユーザは WebSessionView 下部の `ScenePromptsEditorView` から追加できる。
