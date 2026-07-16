---
title: コンパニオンのエージェント定義 (agent.md)
description: コンパニオンを instructions.md ではなく agent.md でエージェントとして定義する仕組みの仕様
derived_from:
  - docs/specs/companions/companion.md
  - docs/decisions/0029-companion-as-agent-definition.md
syncs_with:
  - docs/specs/companions/companion.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# コンパニオンのエージェント定義 (agent.md)

コンパニオンの役割を `instructions.md` ではなく **`agent.md`** という構造化ファイルで定義できる。
`agent.md` が存在するコンパニオンは起動時に「エージェントとして振る舞ってね」という指示コマンドが送られる。

---

## 概要

| ファイル | 用途 |
|---|---|
| `instructions.md` | 従来の自由記述指示書。`を読んで従ってね` コマンドで起動 |
| `agent.md` | 構造化されたエージェント定義。`を読んでエージェントとして振る舞ってね` コマンドで起動 |

コンパニオン起動時に Aidea は `.aidea/claude/companions/<index>/agent.md` の存在を確認し:
- **存在する** → `agent.md を読んでエージェントとして振る舞ってね` を PTY に送信
- **存在しない** → 従来通り `instructions.md を読んで従ってね` を PTY に送信 (フォールバック)

---

## agent.md のフォーマット

YAML frontmatter + Markdown 形式。frontmatter でエージェントのメタデータを宣言し、
本文にロール・プロトコル・制約を記述する。

```
---
name: <コンパニオン表示名と同じ名前>
role: <1 行でこのエージェントの役割>
---

# <役割タイトル>

## ロール

(このエージェントが担う具体的な責務を記述)

## 行動プロトコル

(依頼を受けたときの標準的な応答手順)

## 制約

(やってはいけないこと、スコープ外のこと)
```

frontmatter は必須ではない。Markdown 本文だけでも動作するが、
`name` / `role` を書いておくと他のコンパニオンからハンドオフを受けたときに
識別しやすい。

---

## ファイルの配置

```
<projectRoot>/
└── .aidea/
    └── claude/
        └── companions/
            ├── 0/
            │   ├── agent.md        ← エージェント定義 (これがあれば優先)
            │   └── instructions.md ← 従来の指示書 (agent.md がなければ使用)
            ├── 1/
            │   └── instructions.md ← agent.md なし → フォールバック
            └── ...
```

同一インデックスに `agent.md` と `instructions.md` の両方がある場合は `agent.md` が優先される。
`instructions.md` は残しておいても問題ない (フォールバック・バックアップとして機能する)。

---

## Bundle テンプレート

Aidea には `companion-agent.md` という Bundle テンプレートが付属する。
初回セットアップ処理 ([../backchannels/backchannel.md](../backchannels/backchannel.md)) などから参照して新規プロジェクトのサンプルとして使える。

---

## 起動コマンド仕様

### agent.md が存在する場合

```
.aidea/claude/companions/<index>/agent.md を読んでエージェントとして振る舞ってね
```

### agent.md が存在しない場合 (フォールバック)

```
.aidea/claude/companions/<index>/instructions.md を読んで従ってね
```

起動コマンドの生成は、起動直前に同期的に `agent.md` の存在確認を行って分岐する。

---

## スナップショット復元時の挙動

Aidea 再起動によるスナップショット復元時も同じロジックで起動コマンドを生成する。
再起動後にユーザーが `agent.md` を追加・削除した場合は、次にそのコンパニオンを
起動したタイミングで最新の状態が反映される。

---

## 関連

- [companion.md](./companion.md) — コンパニオン全体仕様・起動フロー
- [../../decisions/0029-companion-as-agent-definition.md](../../decisions/0029-companion-as-agent-definition.md) — 採用理由の ADR
