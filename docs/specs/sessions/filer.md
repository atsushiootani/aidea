---
title: Session 内部状態: Filer
description: FilerSessionState の状態 (selectedFile / expandedURLs)・シングルトン制約・workspace.json 永続化・Scene とレコメンドプロンプト
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/filer.md
  - docs/specs/aspects/persistence.md
  - docs/specs/companions/recommend-mode.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# Session 内部状態: Filer

`filer` Tool の Session は `FilerSessionState` (`@Observable`) として状態を保持する。
**ペイン移動で状態が失われない** ことを保証する。

用語と UI ルールの前提は [ui-rules.md](./ui-rules.md) を、Tool 仕様は [../tools/filer.md](../tools/filer.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `selectedFile` | `URL?` | 現在選択中のファイル/ディレクトリ | ✅ |
| `expandedURLs` | `Set<URL>` | アウトライン上で展開されているノード | ✅ |
| `excludeRules` | `[String]` | 表示・検索の除外パターン (デフォルト + ユーザ追加) | ✅ |
| `userDecorationRules` | `[DecorationRule]` | アイコン / 行背景色のユーザ追加ルール (デフォルトの後に連結 = 後勝ち) | ✅ |
| `undoManager` | `NSUndoManager` (ObservationIgnored) | Filer 操作 (rename / move / delete / create / paste) のアンドゥ・リドゥ履歴 | ✅ (履歴はメモリ上のみ・永続化なし) |
| `registry` | `weak var SessionRegistry?` | Filer ダブルクリック時に Preview を開くための参照 | ✅ |

`excludeRules` のパターン形式・適用範囲・デフォルトは [../tools/filer.md#除外ルール](../tools/filer.md#除外ルール) を参照。

## 永続化

`expandedURLs` / `excludeRules` / `userDecorationRules` は `<projectRoot>/.aidea/workspace.json` (v6) に含めて保存される。
`undoManager` は永続化対象外 (アプリ終了で履歴は失われる)。
`defaultDecorationRules` は Aidea 同梱の定数なので永続化しない。
詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。

## シングルトン制約

`filer` は Window 全体で 1 つだけ。詳細は [ui-rules.md#シングルトン制約](./ui-rules.md#シングルトン制約) を参照。

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `currentScene()` | 場面 |
|---|---|
| `"filer"` | Filer ツール全体 (mode 分岐なし) |

- 初期プロンプトは空配列 (`[]`)、`defaultCompanionIndex` は `0`。
- ユーザは FilerSessionView 下部の `ScenePromptsEditorView` から追加できる。
