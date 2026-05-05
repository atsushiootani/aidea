---
title: "Frontchannel: Scene"
description: レコメンドプロンプトのコンテキストを表す Scene 識別子 ({tool}:{section}:{mode}) の仕様と解決順序・SessionState プロトコル
derived_from:
  - docs/specs/frontchannels/frontchannel.md
syncs_with:
  - docs/specs/aspects/persistence.md
impacts:
  - docs/specs/companions/recommend-mode.md
  - docs/specs/sessions/claude.md
  - docs/specs/sessions/filer.md
  - docs/specs/sessions/git.md
  - docs/specs/sessions/git-diff.md
  - docs/specs/sessions/kit.md
  - docs/specs/sessions/preview.md
  - docs/specs/sessions/terminal.md
  - docs/specs/sessions/web.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# Frontchannel: Scene

> レコメンドプロンプトのコンテキストを表す概念

---

## 概要

**Scene** は、ユーザーが今どの場面にいるかを表す識別子。
Scene に応じたレコメンドプロンプトがコンパニオンの吹き出しに表示される。

---

## Scene 識別子

`{tool}:{section}:{mode}` 形式の文字列。不要な部分は省略し、コロンの連続や末尾コロンは発生しない。

| 構成 | 形式 | 例 |
|------|------|-----|
| ツールのみ | `{tool}` | `filer` |
| ツール + モード | `{tool}:{mode}` | `git:workingChanges` |
| ツール + セクション + モード | `{tool}:{section}:{mode}` | `preview:markdown:view` |

### 具体例

| Scene 識別子 | 場面 |
|-------------|------|
| `git:workingChanges` | Git ツール、Working Changes モード |
| `git:prPreview` | Git ツール、PR Preview モード |
| `gitDiff:workingChanges` | GitDiff ツール、Working Changes モード |
| `gitDiff:prPreview` | GitDiff ツール、PR Preview モード |
| `claude:0` … `claude:8` | Claude ツール、Companion index ごと (0…8 固定) |
| `filer` | Filer ツール |
| `terminal` | Terminal ツール |
| `preview` | Preview ツール |
| `kit` | Kit ツール |
| `web` | Web ツール |
| `preview:markdown:view` | Preview、Markdown、ビューモード (将来拡張余地) |

Claude セッションは Companion と 1:1 で紐付くため、Scene 識別子も Companion index ごとに分ける。これにより Companion の役割別 (例: テスト担当 / レビュー担当) にレコメンドプロンプトを使い分けられる。

---

## 永続化

`workspace.json` v7 の `recommends` フィールドに Scene 識別子 → `SceneConfig` のマッピングを保存する。詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。

```json
{
  "git:workingChanges": { "prompts": ["コミットして", "プッシュして", "PRを作って"], "defaultCompanionIndex": 0 },
  "git:prPreview":      { "prompts": ["PRをマージして", "レビューして"], "defaultCompanionIndex": 0 },
  "filer":              { "prompts": ["このファイルをレビューして"], "defaultCompanionIndex": 0 }
}
```

### 初期値の SSoT

各 Scene のデフォルトプロンプトは **Bundle 同梱の `Aidea/Resources/default-workspace.json` の `recommends` フィールド** を唯一のソースとする。Swift コード側 (SessionState 等) にハードコードしない。

新しい Scene を追加する手順:

1. 該当 SessionState の `currentScene()` で識別子を返すようにする
2. `default-workspace.json` の `recommends` にエントリを追加する

---

## プロンプトの解決順序

1. `workspace.json` の `recommends` にその Scene のエントリがあればそれを使う
   - 起動時に workspace.json が無い場合は `default-workspace.json` から流入したエントリが使われる
2. エントリが無い Scene ではレコメンドなし (Cmd+Enter 無反応)

ハードコードフォールバックは持たない。Scene ごとの初期値はすべて `default-workspace.json` 経由で `RecommendStore` に流入する。

---

## SessionState プロトコル

各 Tool の Session 状態は「現在の Scene 識別子」を返す能力を持つ。RecommendState はこの識別子を使って Scene プロンプトストアから対応するプロンプト一覧を引く。

初期値の二重管理を防ぐため、SessionState 側にデフォルトプロンプトのハードコードは持たない。
