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
last_updated: 2026-07-16
---

# Backchannels (Claude → Aidea 通信) インデックス

Claude が `.aidea/backchannels/` にファイルを書き出して Aidea に通知する、ファイルベースの通信チャネル。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [backchannel.md](./backchannel.md) | Backchannel プロトコル全般 (設計原則・ディレクトリ構造・機能宣言チェーン・ファイル監視) |
| [voicevox.md](./voicevox.md) | Speech メッセージの VOICEVOX 読み上げ実装 |
| [handoff.md](./handoff.md) | Handoff メッセージによる Companion 間タスク受け渡し |
| [output.md](./output.md) | Output メッセージによるレスポンス全文の出力記録 |
| [remind.md](./remind.md) | Remind メッセージによる遅延発火型の音声リマインド (トリガ時刻 = ファイル名のタイムスタンプ) |
| [inbox.md](./inbox.md) | 外部プロセス → Companion の一方向メッセージ (`inbox/*.json`、返信なし) |
| [rpc.md](./rpc.md) | 外部プロセス ⇄ Companion の往復メッセージ (`rpc/req-*.json` / `res-*.txt`、MCP サーバ経由で利用) |
| [companion-roster.md](./companion-roster.md) | aidea.md 内のコンパニオン名簿セクションを Aidea が `companions[].name` に追従して自動更新する仕様 |
| [status.md](./status.md) | Status メッセージによる作業状態のフキダシ表示。Claude Code hooks が書く信頼できる信号 (`status-signal.json`) と Claude 自身が書く自由文字列ラベル (`status-*.json`) の2系統 (issue #281) |

## 関連

- [../frontchannels/](../frontchannels/README.md) — 逆方向 (Aidea → Claude) の通信
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/` 配下のファイル配置
- [../tools/claude.md](../tools/claude.md) — Backchannel を利用する Claude Tool
