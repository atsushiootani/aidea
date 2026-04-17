---
title: Companions インデックス
description: ヘッダに並ぶ 8 体のコンパニオンアイコンとレコメンドモードなど Claude セッション連携 UI のインデックス
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts:
  - docs/specs/companions/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
---

# Companions

Aidea のヘッダに並ぶ **コンパニオン** (8 体のアイコン) とその関連 UI の仕様。
1 体のコンパニオンが 1 つの Claude セッションに紐付き、起動・フォーカス・
レコメンド送信の入口になる。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [companion.md](./companion.md) | コンパニオンの概念・`CompanionConfig` / `CompanionStore` の仕様・起動フロー |
| [recommend-mode.md](./recommend-mode.md) | Cmd+Enter で起動するレコメンド選択 UI (`RecommendState` / `RecommendStore`) |

## 関連

- [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) — Aidea → Claude の送信メカニズム
- [../tools/claude.md](../tools/claude.md) — Claude セッション側の挙動
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/companions.json` / `.aidea/recommends.json`
