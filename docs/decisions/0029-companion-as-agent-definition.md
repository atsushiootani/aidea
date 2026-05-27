---
title: "0029: コンパニオンのエージェント定義に agent.md を採用"
description: コンパニオン起動時に instructions.md の代わりに agent.md でエージェントとして定義できるようにした判断の記録
status: 採用
derived_from:
  - docs/decisions/0022-companion-instructions-as-files.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-27
---

# 0029: コンパニオンのエージェント定義に agent.md を採用

**日付**: 2026-05-27

## 背景

ADR 0022 でコンパニオンの指示書を `instructions.md` として外部ファイル化した。
従来の `instructions.md` は自由記述であり、Claude に「読んで従ってね」という指示を送るだけだった。

Claude の agent 機能 / エージェント定義パターンの普及により、より構造化された形式で
コンパニオンの役割・プロトコル・制約を定義したいというニーズが生じた (Issue #140)。

## 決定

コンパニオン起動時に `.aidea/claude/companions/<index>/agent.md` が存在するかを確認し、

- **存在する** → `agent.md を読んでエージェントとして振る舞ってね` を PTY に送信
- **存在しない** → 従来通り `instructions.md を読んで従ってね` を送信 (フォールバック)

`CompanionInstructions` に `startupCommand(for:projectRoot:)` メソッドを追加し、
全コンパニオン起動経路 (`CompanionView`・`AideaApp`・`WorkspaceSnapshotManager`) を
このメソッドに統一する。

## 理由

### フォールバック設計

破壊的変更を避けるため、既存ユーザーの `instructions.md` は引き続き動作する。
`agent.md` は opt-in: 作成したコンパニオンのみが新しい起動コマンドを受け取る。

### ファイル存在確認の同期実行

起動コマンド生成は PTY に文字列を送る直前の処理であり、I/O コストは低い。
`FileManager.default.fileExists` は同期呼び出しで問題ない。

### `instructions.md` の廃止はしない

両者は共存可能。`agent.md` は上位互換的な定義方法であり、
`instructions.md` を使い続けることも推奨ワークフローとして継続する。

## 代替案

### agent.md を「instructions.md から読み込む」方式

`instructions.md` に `@agent.md を参照` のような記述を書かせる方法。

却下理由: Aidea 側での検出が困難、かつユーザーにとって冗長。

### workspace.json に agent mode フラグを追加する方式

`CompanionConfig` に `isAgentMode: Bool` を持たせる。

却下理由: workspace.json のスキーマバージョンアップが必要になり、
ファイルの存在チェックで十分な要件に対してコストが大きい。

## 影響

- `CompanionInstructions`: `startupCommand(for:projectRoot:)` を追加。`loadCommand(for:)` は内部実装として残す
- `CompanionView.launchCompanion(_:)`: `startupCommand` を使用するよう変更
- `AideaApp.activateCompanion(index:)`: `startupCommand` を使用するよう変更
- `AideaApp.sendRecommendedPrompt(...)`: `projectRoot` パラメータを追加して `startupCommand` を使用
- `AideaApp.dispatchHandoff(...)`: `projectRoot` パラメータを追加して `startupCommand` を使用
- `WorkspaceSnapshotManager.apply(...)`: `startupCommand` を使用するよう変更 (既に `projectRoot` を受け取っている)
