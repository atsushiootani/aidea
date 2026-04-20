---
title: Backchannels (Claude → Aidea 通信) インデックス
description: Backchannel プロトコルと VOICEVOX 読み上げなど Claude → Aidea 通信仕様のインデックス
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts:
  - docs/specs/backchannels/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
---

# Backchannels (Claude → Aidea 通信) インデックス

Claude が `.aidea/backchannels/` にファイルを書き出して Aidea に通知する、ファイルベースの通信チャネル。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [backchannel.md](./backchannel.md) | Backchannel プロトコル全般 (設計原則・ディレクトリ構造・機能宣言チェーン・ファイル監視) |
| [voicevox.md](./voicevox.md) | Speech メッセージの VOICEVOX 読み上げ実装 |

## 関連

- [../frontchannels/](../frontchannels/README.md) — 逆方向 (Aidea → Claude) の通信
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/` 配下のファイル配置
- [../tools/claude.md](../tools/claude.md) — Backchannel を利用する Claude Tool
