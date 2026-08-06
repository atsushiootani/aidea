---
title: Aidea Conventions
description: コーディング規約・設計原則・テスト戦略と、個別機能の実装規約 (implementations/) のインデックス
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts:
  - docs/conventions/*
  - docs/conventions/implementations/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-08-06
---

# Aidea Conventions

Aidea のコードを書く際に従うべき規約とガイドライン。
プロダクト仕様 (何を作るか) は [../specs/](../specs/README.md) を参照。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [coding-style.md](./coding-style.md) | Swift 規約 / プロパティラッパ並び順 / コメント方針 / 並行性 |
| [swift.md](./swift.md) | SwiftUI と AppKit (NSView) の使い分け / 閉じ込めルール |
| [design-principles.md](./design-principles.md) | 設計原則 (Tell Don't Ask / SOLID / GRASP 等) |
| [rules.md](./rules.md) | Always / Confirm First / Never — コードレビュー時のチェックリスト |
| [testing.md](./testing.md) | テスト戦略 / 手動確認チェックリスト |
| [quality-gates.md](./quality-gates.md) | 機械検査 (ビルド / テスト / docs リンク / specs 実装詳細) と検証欄の運用 |
| [autonomous-loop.md](./autonomous-loop.md) | 自律開発ループの範囲 (loop-safe 層) / 1 サイクルの定義 / 撤退条件 / 禁止事項 |

直下はコードベース**全体にまたがる規約**のみを置く。

## implementations/ — 個別機能の実装規約

特定の機能・仕様に紐づく実装規約と実装知見。対応する spec (要件の SSoT) からリンクされる。

| ファイル | 内容 |
|---|---|
| [implementations/focus.md](./implementations/focus.md) | フォーカス契約 ([specs/sessions/focus-contract.md](../specs/sessions/focus-contract.md)) の実装規約 (SessionFocusBridge / setView / クリックモニタ) |
| [implementations/e2e-key-simulation.md](./implementations/e2e-key-simulation.md) | E2E キー入力シミュレーションの知見と再開手順 (TCC / CGEvent / IME) |

※ docs/ 配下の YAML frontmatter 規約は [../LAYOUT.md](../LAYOUT.md#frontmatter-規約) を参照。

## 読む順番 (初見)

1. [design-principles.md](./design-principles.md) — まず思想を掴む
2. [coding-style.md](./coding-style.md) — 表面的な規約
3. [swift.md](./swift.md) — SwiftUI / NSView の使い分け
4. [testing.md](./testing.md) — テストの方針
5. [rules.md](./rules.md) — Always / Confirm First / Never の具体ルール
