---
title: Session 内部状態: Git
description: Git Tool の状態 (mode / treeNodes / selectedPath / fileStats 等)・Scene とレコメンドプロンプト・シングルトン制約・GitDiff との連携
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/git.md
  - docs/specs/sessions/git-diff.md
  - docs/specs/companions/recommend-mode.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-01
---

# Session 内部状態: Git

`git` Tool の Session 状態を管理する。表示モード・ツリーノード・選択パス・ファイル統計などを保持する。
Working changes / PR Preview の 2 モードで、変更ファイルツリーを管理する。

Tool 仕様は [../tools/git.md](../tools/git.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `mode` | `GitMode` (`.workingChanges` / `.prPreview`) | 表示モード | ✅ |
| `treeNodes` | `[GitFileTreeNode]` | 変更ファイルのツリー表現 | ✅ |
| `selectedPath` | `String?` | 選択中のファイルパス (変更時に GitDiff へ伝播) | ✅ |
| `currentBranch` | `String` | 現在のブランチ名 | ✅ |
| `fileStats` | `[String: (added: Int, deleted: Int)]` | ファイルごとの追加/削除行数 (未ステージ差分。PR Preview では main との全差分) | ✅ |
| `stagedFileStats` | `[String: (added: Int, deleted: Int)]` | ステージ済みファイルごとの追加/削除行数 (Working Changes 専用。staged 差分のみ) | ✅ |
| `registry` | `weak var SessionRegistry?` | Diff ビュー連携用 | — |
| 選択変更コールバック | — | GitDiff への選択パス伝播 | — |
| 既読状態変更コールバック | — | GitDiff への既読状態伝播 | — |

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `mode` | `currentScene()` |
|---|---|
| `.workingChanges` | `"git:workingChanges"` |
| `.prPreview` | `"git:prPreview"` |

各 Scene のデフォルトプロンプトは Bundle 同梱 `Aidea/Resources/default-workspace.json` の `recommends` を SSoT とする (Swift コードへのハードコードは禁止)。詳細は [../frontchannels/scene.md](../frontchannels/scene.md) と [../companions/recommend-mode.md](../companions/recommend-mode.md) を参照。

永続化は `workspace.json` v7 の `recommends` フィールド経由。GitDiff ツール ([git-diff.md](./git-diff.md)) とは Scene キーが独立しているため、両方を個別にカスタマイズできる。

## シングルトン制約

`git` は Window 全体で 1 つだけ。詳細は [ui-rules.md#シングルトン制約](./ui-rules.md#シングルトン制約) を参照。

## GitDiff との連携

選択ファイルが変わるとコールバックを通じて [git-diff.md](./git-diff.md) の GitDiff Session に伝播する。
