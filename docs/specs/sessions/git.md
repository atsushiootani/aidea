---
title: Session 内部状態: Git
description: GitSessionState の状態 (mode / treeNodes / selectedPath / fileStats 等)・Scene とレコメンドプロンプト・シングルトン制約・GitDiff との連携
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
last_updated: 2026-07-13
---

# Session 内部状態: Git

`git` Tool の Session が保持する状態。
Working Changes / PR Preview の 2 モードで、変更ファイルツリーを管理する。

Tool 仕様は [../tools/git.md](../tools/git.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| 状態 | 用途 | ペイン移動で保持 |
|---|---|---|
| 表示モード | Working Changes / PR Preview のどちらか | ✅ |
| 変更ファイルツリー | 変更ファイルのツリー表現 | ✅ |
| 選択中ファイルパス | 選択中のファイルパス (変更時に選択変更通知を発火) | ✅ |
| 現在のブランチ名 | 現在チェックアウトしているブランチ名 | ✅ |
| 差分統計 | ファイルごとの追加/削除行数 (未ステージ差分。PR Preview では main との全差分) | ✅ |
| ステージ済み差分統計 | ステージ済みファイルごとの追加/削除行数 (Working Changes 専用。staged 差分のみ) | ✅ |
| レジストリ参照 | Diff ビュー連携用の [SessionRegistry](../glossary.md) への弱参照 | — |
| 選択変更通知 | 選択ファイルの変更を GitDiff 側へ伝えるコールバック | — |
| 既読状態変更通知 | 既読状態の変更を伝えるコールバック | — |
| リロード完了通知 | バックグラウンドリロード完了時に View にツリー表示の再読込を促すコールバック | — |
| 読み込み中フラグ | バックグラウンドリロード中かどうか | — |
| 追加表示フラグ | 表示上限 (50 件) を超える変更ファイルが存在する場合に立つ。View が「さらに表示」ボタンを出す判断に使う | — |

## Scene とレコメンドプロンプト

セッション共通の仕組み ([../frontchannels/scene.md](../frontchannels/scene.md)) で、Cmd+Enter のレコメンド送信に対応する。

| 表示モード | Scene 識別子 |
|---|---|
| Working Changes | `"git:workingChanges"` |
| PR Preview | `"git:prPreview"` |

各 Scene のデフォルトプロンプトは Bundle 同梱の `default-workspace.json` の `recommends` を SSoT とする (コードへのハードコードは禁止)。詳細は [../frontchannels/scene.md](../frontchannels/scene.md) と [../companions/recommend-mode.md](../companions/recommend-mode.md) を参照。

永続化は `workspace.json` v7 の `recommends` フィールド経由。GitDiff ツール ([git-diff.md](./git-diff.md)) とは Scene キーが独立しているため、両方を個別にカスタマイズできる。

## シングルトン制約

`git` は Window 全体で 1 つだけ。詳細は [ui-rules.md#シングルトン制約](./ui-rules.md#シングルトン制約) を参照。

## GitDiff との連携

選択ファイルが変わると選択変更通知を通じて GitDiff セッション状態 ([git-diff.md](./git-diff.md)) に伝播する。
