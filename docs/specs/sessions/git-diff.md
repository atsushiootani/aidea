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
  - docs/specs/companions/recommend-mode.md
  - docs/specs/aspects/sort-order.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# Session 内部状態: GitDiff

`gitDiff` Tool の Session が保持する状態。
Git ツール経由で開かれる差分ビュー (diff2html レンダリング)。

Tool 仕様の背景は [../tools/git.md](../tools/git.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。
diff2html の採用理由は [ADR 0004](../../decisions/0004-git-diff-with-diff2html.md) を参照。

## 状態

| 状態 | 用途 | ペイン移動で保持 |
|---|---|---|
| 表示モード | 対応する Git ツールのモード (Working Changes / PR Preview) | ✅ |
| 差分出力 | `git diff` の生出力 | ✅ |
| スクロール指示 | 指定ファイルへスクロールさせる一時指示 | — |
| 既読ファイル集合 | 既読になったファイルの集合 (変更時に既読状態変更通知を発火) | ✅ |
| フォーカス中ファイル | フォーカス中のファイル | ✅ |
| レジストリ参照 | Git セッションへの逆参照用の [SessionRegistry](../glossary.md) への弱参照 | — |

## Scene とレコメンドプロンプト

セッション共通の仕組み ([../frontchannels/scene.md](../frontchannels/scene.md)) で、Cmd+Enter のレコメンド送信に対応する。

| 表示モード | Scene 識別子 |
|---|---|
| Working Changes | `"gitDiff:workingChanges"` |
| PR Preview | `"gitDiff:prPreview"` |

各 Scene のデフォルトプロンプトは Bundle 同梱の `default-workspace.json` の `recommends` を SSoT とする (コードへのハードコードは禁止)。詳細は [../frontchannels/scene.md](../frontchannels/scene.md) と [../companions/recommend-mode.md](../companions/recommend-mode.md) を参照。

Scene キー (`gitDiff:*`) が Git ツール (`git:*`) と別のため、`workspace.json` v7 の `recommends` では**独立した 2 エントリ**として永続化される。ユーザは Git / GitDiff それぞれでプロンプトをカスタマイズする必要がある (Issue #74 の方針)。

## ファイル表示順序

Working Changes モードで全ファイルを表示するとき、**Git パネルのツリーと同じ Finder 互換自然順**でファイルを並べる。
`git diff --cached` (staged) → `git diff` (unstaged) → untracked の順に diff を収集した後、
ファイルパスを Finder 互換自然順の昇順で並び替えてから diff2html に渡す。
同一ファイルに staged と unstaged の両セクションがある場合は staged を先に表示する (安定ソート)。

PR Preview モードも同様に、`git diff main...HEAD` の出力をファイルパスで自然順に並び替えてから diff2html に渡す。

比較ルール・共通ヘルパは [../aspects/sort-order.md](../aspects/sort-order.md) を参照。

## プレビュージャンプ

フォーカス中ファイルが設定されている状態で **Enter** を押すと、対象ファイルを sibling 配置で Preview タブに開く。

- プロジェクトルートとフォーカス中ファイルのパスからフルパス URL を構築する
- ファイルが存在しない場合 (削除済み・リネーム後の旧パス等) は何もしない
- Preview は **GitDiff と同じペインの右隣に新規タブとして挿入**される (GitDiff 作業中に他ペインへフォーカスを奪われない方が体感が自然なため、ターミナルと同じポリシー)
- 同じ URL の Preview が既に存在する場合は dedupe (新規作成せずアクティブ化)

挙動の詳細は [active-session.md#preview-内から-preview-を開く場合-sibling-配置](./active-session.md#preview-内から-preview-を開く場合-sibling-配置) を参照。

## 追加制約

`gitDiff` はペインの `+` メニューに載らず、**Git ツール経由でしか開けない**。
詳細は [ui-rules.md#シングルトン制約](./ui-rules.md#シングルトン制約) を参照。
