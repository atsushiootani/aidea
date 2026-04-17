---
title: Session 内部状態: Git
description: GitSessionState の状態 (mode / treeNodes / selectedPath / fileStats 等)・シングルトン制約・GitDiff との連携
derived_from:
  - docs/specs/sessions/ui-rules.md
syncs_with:
  - docs/specs/tools/git.md
  - docs/specs/sessions/git-diff.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
---

# Session 内部状態: Git

`git` Tool の Session は `GitSessionState` (`@Observable`) として状態を保持する。
Working changes / PR Preview の 2 モードで、変更ファイルツリーを管理する。

Tool 仕様は [../tools/git.md](../tools/git.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `mode` | `GitMode` (`.workingChanges` / `.prPreview`) | 表示モード | ✅ |
| `treeNodes` | `[GitFileTreeNode]` | 変更ファイルのツリー表現 | ✅ |
| `selectedPath` | `String?` | 選択中のファイルパス (変更時に `onSelectedPathChanged` を発火) | ✅ |
| `currentBranch` | `String` | 現在のブランチ名 | ✅ |
| `fileStats` | `[String: (added: Int, deleted: Int)]` | ファイルごとの追加/削除行数 | ✅ |
| `registry` | `weak var SessionRegistry?` | Diff ビュー連携用 | — |
| `onSelectedPathChanged` | `((String?) -> Void)?` (ObservationIgnored) | 選択変更コールバック | — |
| `onViewedChanged` | `(() -> Void)?` (ObservationIgnored) | 既読状態変更コールバック | — |

## シングルトン制約

`git` は Window 全体で 1 つだけ。詳細は [ui-rules.md#シングルトン制約](./ui-rules.md#シングルトン制約) を参照。

## GitDiff との連携

選択ファイルが変わると `onSelectedPathChanged` を通じて [git-diff.md](./git-diff.md) (`GitDiffSessionState`) に伝播する。
