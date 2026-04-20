---
title: "0002: コードエディタ機能を持たない"
description: JetBrains/Neovim 等の既存エディタに任せて Aidea 本体にはコードエディタ機能を実装しない判断
status: 採用
derived_from:
  - docs/foundation/vision.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-08
---

# 0002: コードエディタ機能を持たない

**日付**: 2026-04-08

## 背景
JetBrains 系 IDE を現在使用しているが、将来的に離脱予定。一方で Aidea にフルスペックのエディタを実装するのは過大な労力。

## 判断
Aidea は **コードエディタを持たない**。エディタは別プロセス（JetBrains、Neovim、その他）に任せる。

## 理由
1. エディタ実装は LSP、シンタックスハイライト、折りたたみ、補完等で数百時間レベル
2. 既存のエディタで十分高機能
3. Aidea の目的は「AI エージェント連携の統合環境」であり「エディタを持つこと」ではない

## トレードオフ
- エディタとの連携は別途必要（ファイル選択時に外部エディタで開く等）
- エディタ内でしか取れない情報（カーソル位置等）は取れない
