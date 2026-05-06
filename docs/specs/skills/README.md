---
title: Skills 仕様
description: Claude Code スキル (.claude/commands/) の仕様を機能別に記述するカテゴリ。各スキルが何をするか・どの状態ファイルを読み書きするかを定義する
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-06
---

# Skills 仕様

`.claude/commands/` に置かれる Claude Code スキルの仕様を機能別に記述する。

各スキルは Companion のセッション内で `/スキル名` として実行するか、ルーティン (cron 等) 経由で定期起動する。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [concier-schedule-voice.md](./concier-schedule-voice.md) | concier-chan によるスケジュール音声リマインド機能 |
