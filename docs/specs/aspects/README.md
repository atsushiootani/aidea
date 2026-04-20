---
title: Aspects (横断的関心事) インデックス
description: 複数機能群にまたがる仕様文書のディレクトリインデックスと更新ルール
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts:
  - docs/specs/aspects/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
---

# Aspects (横断的関心事) インデックス

複数の機能群（tools / sessions / companions 等）にまたがる仕様を集約する。

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| [keybindings.md](./keybindings.md) | 全キーボードショートカット・マウス操作の一覧 |
| [persistence.md](./persistence.md) | データ永続化仕様（UserDefaults / Keychain / `.aidea/`） |

## 更新ルール

- 機能群でキー操作やマウス操作を追加・変更したら **keybindings.md** も更新する
- 永続化データを追加・変更したら **persistence.md** も更新する
- `/aidea.docs-healthcheck` で機能群との不整合がフラグされる
