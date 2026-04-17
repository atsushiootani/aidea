---
title: "0005: Obsidian 連携は URL スキーム + 直接ファイル操作のハイブリッド"
description: Obsidian vault を URL スキームで開き、作成/更新はファイル直書きで行う連携方針
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-08
---

# 0005: Obsidian 連携は URL スキーム + 直接ファイル操作のハイブリッド

**日付**: 2026-04-08

## 検討案
1. URL スキーム（`obsidian://`）のみ
2. Vault のファイルを直接読み書き
3. Local REST API プラグイン使用

## 判断
**1 + 2 のハイブリッド**。

## 理由
- 新規作成・更新はファイル直書きが最速
- 「編集するために Obsidian で開く」は URL スキーム
- Local REST API は追加プラグイン依存で過剰、将来必要になったら追加検討

## トレードオフ
- Vault パスを手動設定する必要がある
- Obsidian 側のリンクグラフが外部更新でリビルドされる（問題ないはず）
