---
title: Session 内部状態: Web
description: WebSessionState の状態 (url / WKWebView キャッシュ) と PaneView ZStack による DOM 維持・workspace.json 永続化・Scene とレコメンドプロンプト
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/decisions/0015-wkwebview-scope-and-chrome-coexistence.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/web.md
  - docs/specs/aspects/persistence.md
  - docs/specs/companions/recommend-mode.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-10
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

## 永続化

現在 URL は `<projectRoot>/.aidea/workspace.json` に保存される。詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `currentScene()` | 場面 |
|---|---|
| `"web"` | Web ツール全体 (URL で分岐しない) |

- 初期プロンプトは空配列 (`[]`)、`defaultCompanionIndex` は `0`。
- ユーザは WebSessionView 下部の `ScenePromptsEditorView` から追加できる。
