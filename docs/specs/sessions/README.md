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
last_updated: 2026-05-05
---

# Session (sessions/) インデックス

Aidea の **Session 概念** に関する仕様を集約。
Session とは何かの用語定義は [../glossary.md](../glossary.md) を参照。

## 横断ドキュメント

| ファイル | 内容 |
|---|---|
| [session.md](./session.md) | `Session` (汎用クラス) と `SessionState` (Tool 固有実装) の関係・役割分担・ライフサイクル |
| [ui-rules.md](./ui-rules.md) | 5 概念モデル / シングルトン制約 / 右クリック / 選択・フォーカス / Emacs ナビ |
| [active-session.md](./active-session.md) | アクティブ Session の切替・履歴 (50 件) ・Filer ダブルクリック時の挙動・Preview 開き規約 |
| [focus-contract.md](./focus-contract.md) | Session 間の一貫性を担保する `@FocusState` / `firstResponder` の契約 (C1 / C2 / C3) |

## Tool ごとの SessionState

各 Tool の SessionState (保持プロパティ・ペイン移動での保持・永続化) を 1 ファイルに記述。

| ファイル | Tool |
|---|---|
| [filer.md](./filer.md) | Filer |
| [kit.md](./kit.md) | Kit |
| [terminal.md](./terminal.md) | Terminal |
| [claude.md](./claude.md) | Claude |
| [web.md](./web.md) | Web |
| [preview.md](./preview.md) | Preview |
| [git.md](./git.md) | Git |
| [git-diff.md](./git-diff.md) | GitDiff |
