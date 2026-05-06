---
title: "0026: コンパニオンをエージェント定義 (agent.md) で記述できるようにする"
description: コンパニオンの起動定義に YAML frontmatter + Markdown の agent.md 形式を追加する設計判断。instructions.md は後方互換で残す
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-06
---

# 0026: コンパニオンをエージェント定義 (agent.md) で記述できるようにする

**日付**: 2026-05-06

## 背景

ADR 0022 でコンパニオン指示を `.aidea/claude/companions/<index>/instructions.md` に外部化した。
`instructions.md` はプレーンな Markdown であり、コンパニオンの「ロール」「使用モデル」といった
メタ情報を構造化できない。

一方、プロジェクトルートの `agents/` ディレクトリには YAML frontmatter + Markdown 本文 形式の
定義ファイルが既に存在する (`code-reviewer.md` / `test-engineer.md` / `security-auditor.md`)。

## 問題

1. **メタ情報の欠如**: `instructions.md` は本文のみ。コンパニオンが「テスト担当」「レビュー担当」
   かをファイル単体から読み取れない
2. **一貫性のなさ**: プロジェクトの `agents/*.md` はエージェント定義形式を使うが、
   コンパニオンは独自形式
3. **再利用の難しさ**: `agents/` の既存定義をコンパニオンで流用しようとすると手動で中身をコピーするしかない

## 決定

各コンパニオンが `.aidea/claude/companions/<index>/agent.md` を任意で持てるようにする。
`agent.md` が存在する場合、起動コマンドをエージェント定義読み込み形式に切り替える。
`agent.md` が存在しない場合は `instructions.md` コマンドにフォールバックし、後方互換を維持する。

```
.aidea/claude/companions/<index>/
├── instructions.md   # 後方互換。agent.md がなければこちらを使う
└── agent.md          # 新規。YAML frontmatter + Markdown 本文 (任意)
```

`CompanionInstructions` に `startupCommand(for:projectRoot:)` を追加し、
ファイル存在確認 → 適切なコマンド生成を集約する。
既存の `loadCommand(for:)` は廃止せず、`agent.md` 不在時のフォールバックとして残す。

## 結果

- **構造化**: `agent.md` で `name` / `description` / `model` を frontmatter に書ける
- **一貫性**: `agents/*.md` と同じ形式で書ける。ノウハウが共有できる
- **後方互換**: `agent.md` を作らなければ既存の `instructions.md` 挙動をそのまま維持
- **opt-in**: `BackchannelSetup` は `agent.md` を自動生成しない。ユーザが明示的に作成する

## 不採用案

| 案 | 理由 |
|---|---|
| `instructions.md` に frontmatter を追加 | `BackchannelSetup` が自動生成するファイルに frontmatter を混入させると、シンプルに書きたいユーザへの摩擦が増える。別ファイルにして opt-in にする方がクリーン |
| `CompanionConfig` に `agentFile: String?` を追加 | `workspace.json` に Aidea 専用フィールドが増える。ファイル存在確認でフォールバックする方が宣言不要でシンプル |
| `agents/` の定義をコンパニオン起動時に自動読み込み | 対応テーブル管理が必要になる。明示ファイルの方が透明性が高い |

## 関連

- [ADR 0022](./0022-companion-instructions-as-files.md) — instructions.md 外部化の前提
- [docs/specs/companions/agent-definition.md](../specs/companions/agent-definition.md) — この ADR の結果として書かれた仕様
- [docs/specs/companions/companion.md](../specs/companions/companion.md) — CompanionConfig/CompanionStore 全体仕様
