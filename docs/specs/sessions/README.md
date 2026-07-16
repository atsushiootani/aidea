---
title: Session (sessions/) インデックス
description: Session 概念と各 Tool ごとの SessionState 仕様ファイルのインデックス
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts:
  - docs/specs/sessions/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# Session (sessions/) インデックス

Aidea の **Session 概念** に関する仕様を集約。
Session とは何かの用語定義は [../glossary.md](../glossary.md) を参照。

## 横断ドキュメント

| ファイル | 内容 |
|---|---|
| [session.md](./session.md) | Session (汎用の入れ物) と SessionState (Tool 固有の状態) の関係・役割分担・ライフサイクル |
| [ui-rules.md](./ui-rules.md) | 5 概念モデル / シングルトン制約 / 右クリック / 選択・フォーカス / Emacs ナビ |
| [active-session.md](./active-session.md) | アクティブ Session の切替・履歴 (50 件) ・Filer ダブルクリック時の挙動・Preview 開き規約 |
| [focus-contract.md](./focus-contract.md) | キー入力が常にアクティブ Session だけに届くことを担保する契約 (C1 / C2 / C3) |

## Tool ごとの Session 内部状態

各 Tool の Session が保持する状態 (保持する内容・ペイン移動での保持・永続化) を 1 ファイルに記述。

| ファイル | 内容 |
|---|---|
| [filer.md](./filer.md) | Filer セッション状態 |
| [kit.md](./kit.md) | Kit セッション状態 |
| [terminal.md](./terminal.md) | Terminal セッション状態 |
| [claude.md](./claude.md) | Claude セッション状態 |
| [web.md](./web.md) | Web セッション状態 |
| [preview.md](./preview.md) | Preview セッション状態 |
| [git.md](./git.md) | Git セッション状態 |
| [git-diff.md](./git-diff.md) | GitDiff セッション状態 |
