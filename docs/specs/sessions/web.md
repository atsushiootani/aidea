# Session 内部状態: Web

`web` Tool の Session は `WebSessionState` (`@Observable`) として状態を保持する。
**ペイン移動で WKWebView の状態 (ページ・Cookie・スクロール位置) が失われない** ことを保証する。

共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `url` | `URL` | 現在表示中の URL (初期値: `https://www.apple.com`) | ✅ |
| `cached` | `WKWebView?` (ObservationIgnored) | 遅延生成した WKWebView。`isInspectable = true` | ✅ |
| `urlObservation` | `NSKeyValueObservation?` (ObservationIgnored) | `WKWebView.url` の KVO | ✅ |
| `sessionID` | `SessionID?` (ObservationIgnored) | 自身の ID (逆参照用) | ✅ |
| `webView` | `WKWebView` (computed) | `cached` の lazy アクセサ | — |

## ペイン移動で状態を失わない仕組み

Terminal と同様に `PaneView` の ZStack + `opacity(0)` 方式。NSView が生存し続けるので
**WKWebView の DOM・JavaScript 実行コンテキスト・メディア再生が中断されない**。

## 永続化

現在 URL は `<projectRoot>/.aidea/workspace.json` に保存される。詳細は [../persistence.md](../persistence.md) を参照。
