---
title: Session 内部状態: Terminal
description: TerminalSessionState の PTY + SwiftTerm キャッシュ方式と PaneView ZStack による状態維持・Scene とレコメンドプロンプト
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/architecture.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/terminal.md
  - docs/specs/companions/recommend-mode.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# Session 内部状態: Terminal

`terminal` Tool の Session は `TerminalSessionState` (`@Observable`) として状態を保持する。
**ペイン移動で PTY バッファを含む状態が失われない** ことを保証する。

Tool 仕様は [../tools/terminal.md](../tools/terminal.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `cached` | `PersistentTerminalView?` (ObservationIgnored) | 遅延生成した PTY + SwiftTerm 端末 View。**同一インスタンスを使い回すことで PTY バッファが保たれる** | ✅ |
| `terminalView` | `PersistentTerminalView` (computed) | `cached` の lazy アクセサ。未生成ならここで生成 | — |

## ペイン移動で状態を失わない仕組み

- `PaneView` が全タブを ZStack で常時レンダリング (`opacity(0)` + `allowsHitTesting(false)` で非アクティブを隠す)
- NSView が superview から外れないので **PTY バッファが常に生存** する
- 詳細は [../architecture.md#ui-レイアウトのアーキ上の注意](../architecture.md#ui-レイアウトのアーキ上の注意) を参照

## 永続化

PTY バッファは揮発性 (永続化しない)。ターミナルを閉じれば PTY プロセスも終了する。

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `currentScene()` | 場面 |
|---|---|
| `"terminal"` | Terminal ツール全体 (mode 分岐なし) |

- 初期プロンプトは空配列 (`[]`)。ユーザは TerminalSessionView 下部の `ScenePromptsEditorView` から追加できる。
- `defaultCompanionIndex` 初期値は `0`。
