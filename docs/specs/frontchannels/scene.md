---
title: "Frontchannel: Scene"
description: レコメンドプロンプトのコンテキストを表す Scene 識別子 ({tool}:{section}:{mode}) の仕様と解決順序・SessionState プロトコル
derived_from:
  - docs/specs/frontchannels/frontchannel.md
syncs_with:
  - docs/specs/companions/recommend-mode.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
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
| `filer` | Filer ツール |
| `terminal` | Terminal ツール |
| `preview:markdown:view` | Preview、Markdown、ビューモード |

---

## 永続化

`.aidea/recommends.json` に Scene 識別子 → プロンプト配列のマッピングを保存する。

```json
{
  "git:workingChanges": ["コミットして", "プッシュして", "PRを作って"],
  "git:prPreview": ["PRをマージして", "レビューして"],
  "filer": ["このファイルをレビューして"]
}
```

---

## プロンプトの解決順序

1. `.aidea/recommends.json` にその Scene のエントリがあればそれを使う
2. なければ SessionState のデフォルト値（ハードコード）を使う
3. デフォルト値もなければレコメンドなし（Cmd+Enter 無反応）

---

## SessionState プロトコル

```swift
protocol SessionState {
    /// 現在の Scene 識別子を返す
    func currentScene() -> String?
    /// デフォルトのレコメンドプロンプトを返す
    func recommendedPrompts() -> [String]
}
```

RecommendState は `currentScene()` で識別子を取得し、RecommendStore から対応するプロンプトを引く。
