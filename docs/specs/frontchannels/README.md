---
title: Frontchannels (Aidea → Claude 通信) インデックス
description: PTY send 経由の Aidea → Claude 通信と Scene ベースのレコメンド解決仕様のインデックス
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts:
  - docs/specs/frontchannels/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
---

# Frontchannels (Aidea → Claude 通信)

Aidea が PTY の `send(txt:)` 経由で Claude にプロンプトを送る通信チャネル。Backchannel の逆方向。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [frontchannel.md](./frontchannel.md) | PTY への送信メカニズム全般 |
| [scene.md](./scene.md) | レコメンドプロンプトを解決する Scene 識別子の仕様 |

## 関連

- [../backchannels/](../backchannels/README.md) — 逆方向 (Claude → Aidea) の通信
- [../companions/recommend-mode.md](../companions/recommend-mode.md) — Cmd+Enter レコメンド選択 UI
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/recommends.json` の永続化
