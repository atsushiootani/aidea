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
last_updated: 2026-05-20
---

# Aspects (横断的関心事) インデックス

複数の機能群（tools / sessions / companions 等）にまたがる仕様を集約する。

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| [keybindings.md](./keybindings.md) | 全キーボードショートカット・マウス操作の一覧 |
| [persistence.md](./persistence.md) | データ永続化仕様（UserDefaults / Keychain / `.aidea/`） |
| [sort-order.md](./sort-order.md) | List UI のソート規約 (Finder 互換自然順) と共通ヘルパの SSoT |
| [view-hierarchy.md](./view-hierarchy.md) | 実装上の SwiftUI / AppKit View の親子関係を AA で図示したリファレンス |
| [stale-docs-notification.md](./stale-docs-notification.md) | Swift 変更コミット時に docs/specs 未更新を検出して警告する git post-commit hook の仕様 |

## 更新ルール

- 機能群でキー操作やマウス操作を追加・変更したら **keybindings.md** も更新する
- 永続化データを追加・変更したら **persistence.md** も更新する
- 新しい List UI を追加したり、ソートのキー / 比較関数を変更したら **sort-order.md** も更新する
- View ファイルを追加・削除したり、View の親子関係を変更したら **view-hierarchy.md** も更新する
- `.githooks/post-commit` の検出ロジック (Swift 変更 vs docs/specs 変更) を変更したら **stale-docs-notification.md** も更新する
- `/aidea.docs-healthcheck` で機能群との不整合がフラグされる
