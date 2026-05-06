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
last_updated: 2026-05-06
---

# Aspects (横断的関心事) インデックス

複数の機能群（tools / sessions / companions 等）にまたがる仕様を集約する。

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| [ci-cd.md](./ci-cd.md) | GitHub Actions xcodebuild CI パイプラインと自動修正スキルの仕様 |
| [keybindings.md](./keybindings.md) | 全キーボードショートカット・マウス操作の一覧 |
| [persistence.md](./persistence.md) | データ永続化仕様（UserDefaults / Keychain / `.aidea/`） |
| [sort-order.md](./sort-order.md) | List UI のソート規約 (Finder 互換自然順) と共通ヘルパの SSoT |
| [stale-docs-notification.md](./stale-docs-notification.md) | Swift 変更時に docs/specs が未更新なら警告する git post-commit hook の仕様 |
| [view-hierarchy.md](./view-hierarchy.md) | 実装上の SwiftUI / AppKit View の親子関係を AA で図示したリファレンス |

## 更新ルール

- 機能群でキー操作やマウス操作を追加・変更したら **keybindings.md** も更新する
- 永続化データを追加・変更したら **persistence.md** も更新する
- CI パイプラインの設定を変更したら **ci-cd.md** も更新する
- 新しい List UI を追加したり、ソートのキー / 比較関数を変更したら **sort-order.md** も更新する
- View ファイルを追加・削除したり、View の親子関係を変更したら **view-hierarchy.md** も更新する
- `.githooks/post-commit` の検出ロジックや警告メッセージを変更したら **stale-docs-notification.md** も更新する
- `/aidea.docs-healthcheck` で機能群との不整合がフラグされる
