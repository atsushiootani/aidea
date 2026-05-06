---
title: コンパニオンのエージェント定義 (agent.md)
description: companions/<index>/agent.md による構造化エージェント定義の仕様。YAML frontmatter でコンパニオンのロール・モデル等を明示し、instructions.md より情報豊富な起動時定義として機能する
derived_from:
  - docs/decisions/0022-companion-instructions-as-files.md
  - docs/decisions/0026-companion-as-agent-definition.md
syncs_with:
  - docs/specs/companions/companion.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-06
---

# コンパニオンのエージェント定義 (agent.md)

## 概要

各コンパニオンは `instructions.md` の代わりに `agent.md` を持てる。
`agent.md` は `agents/` ディレクトリのサブエージェント定義と同じ **YAML frontmatter + Markdown 本文** 形式を使う。

```
.aidea/claude/companions/
└── <index>/
    ├── instructions.md   # 従来の指示書 (agent.md がなければこちらが使われる)
    └── agent.md          # エージェント定義 (任意。あれば instructions.md より優先)
```

`agent.md` が存在する場合、Aidea は起動時に次のコマンドを PTY に送る:

```
.aidea/claude/companions/<index>/agent.md を読んで、その定義に従ってエージェントとして動いてね
```

`agent.md` が存在しない場合は従来通り `instructions.md` コマンドにフォールバックする。

---

## agent.md フォーマット

### 必須フィールド

| フィールド | 型 | 意味 |
|---|---|---|
| `name` | string | エージェント名 (kebab-case 推奨。例: `test-engineer`) |
| `description` | string | このコンパニオンの役割の説明 |

### 任意フィールド

| フィールド | 型 | 意味 |
|---|---|---|
| `model` | string | 使用モデル (例: `claude-opus-4-7`)。省略時はセッションのデフォルト |

### 本文 (Markdown)

YAML frontmatter の後ろに Claude に与えるシステムプロンプトを書く。
`aidea.md` / `speech.md` 等の共有指示書への参照も同様に記述する。

### サンプル

```markdown
---
name: test-engineer
description: テストを担当するコンパニオン。TDD で実装の品質を担保する。
---

# テストエンジニア

.aidea/claude/aidea.md と .aidea/claude/speech.md と .aidea/claude/context.md を読んで従ってね。

## 役割

あなたはテスト担当コンパニオンです。
- 新機能に対して failing test を先に書く
- テストが通ったことを確認してから完了とみなす
- agents/test-engineer.md のスキルを参照して動く
```

---

## プロジェクトレベルのエージェント定義との関係

`<projectRoot>/agents/` には再利用可能なエージェント定義
(`code-reviewer.md` / `test-engineer.md` / `security-auditor.md` など) が置かれる。
コンパニオンの `agent.md` 本文でこれらを `Read` 参照することで、定義の重複を避けられる:

```markdown
---
name: code-reviewer
description: コードレビューを担当するコンパニオン
---

agents/code-reviewer.md を読んで、その定義に従って動いてね。
さらに .aidea/claude/context.md も参照してプロジェクト固有の事情を把握してね。
```

---

## 作成方法

Aidea は `agent.md` を自動生成しない (opt-in)。ユーザが手動で作成する。
`CompanionEditView` の「指示書を開く」ボタンで `instructions.md` を開いた後、
同ディレクトリに `agent.md` を新規作成する。

---

## フォールバック

| 状態 | 動作 |
|---|---|
| `agent.md` が存在する | `agent.md` コマンドで起動 |
| `agent.md` がなく `instructions.md` がある | `instructions.md` コマンドで起動 (従来通り) |
| どちらもない | `BackchannelSetup` が `instructions.md` テンプレを生成するため通常は発生しない |

---

## 関連

- [companion.md](./companion.md) — CompanionConfig / CompanionStore の全体仕様
- [../../decisions/0026-companion-as-agent-definition.md](../../decisions/0026-companion-as-agent-definition.md) — この設計を採用した ADR
- [../../decisions/0022-companion-instructions-as-files.md](../../decisions/0022-companion-instructions-as-files.md) — instructions.md 外部化の ADR (前提)
