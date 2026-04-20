---
title: Session 内部状態: GitDiff
description: GitDiffSessionState の状態 (mode / diffOutput / viewedFiles / focusedFile 等)・Scene とレコメンドプロンプト・Git ツール経由でのみ開く制約
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/frontchannels/scene.md
  - docs/decisions/0004-git-diff-with-diff2html.md
syncs_with:
  - docs/specs/tools/git.md
  - docs/specs/sessions/git.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-20
---

# Session 内部状態: GitDiff

`gitDiff` Tool の Session は `GitDiffSessionState` (`@Observable`) として状態を保持する。
Git ツール経由で開かれる差分ビュー (diff2html レンダリング)。

Tool 仕様の背景は [../tools/git.md](../tools/git.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。
diff2html の採用理由は [ADR 0004](../../decisions/0004-git-diff-with-diff2html.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `mode` | `GitMode` (`.workingChanges` / `.prPreview`) | 対応する Git ツールのモード | ✅ |
| `diffOutput` | `String` | `git diff` の生出力 | ✅ |
| `scrollToFile` | `String?` | 指定ファイルへスクロール指示 | — |
| `viewedFiles` | `Set<String>` | 既読ファイル集合 (変更時 `onViewedChanged` 発火) | ✅ |
| `focusedFile` | `String?` | フォーカス中のファイル | ✅ |
| `registry` | `weak var SessionRegistry?` | Git セッションへの逆参照 | — |

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `mode` | `currentScene()` | `recommendedPrompts()` (デフォルト) |
|---|---|---|
| `.workingChanges` | `"gitDiff:workingChanges"` | `["コミットして", "プッシュして", "PRを作って"]` |
| `.prPreview` | `"gitDiff:prPreview"` | `["PRをマージして", "レビューして"]` |

デフォルトプロンプトは [git.md](./git.md) と同じだが、Scene キー (`gitDiff:*`) が Git ツール (`git:*`) と別のため、`workspace.json` v3 の `recommends` では**独立した 2 エントリ**として永続化される。ユーザは Git / GitDiff それぞれでプロンプトをカスタマイズする必要がある (Issue #74 の方針)。

## 追加制約

`gitDiff` は `PaneView` の `+` メニューに載らず、**Git ツール経由でしか開けない**。
詳細は [ui-rules.md#シングルトン制約](./ui-rules.md#シングルトン制約) を参照。
