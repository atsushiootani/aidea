---
title: Session 内部状態: Kit
description: KitSessionState の状態 (expandedSections / expandedGroups / selection) と 4 種ローダ・FileWatcher 自動更新・workspace.json 永続化・Scene とレコメンドプロンプト
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/kit.md
  - docs/specs/aspects/persistence.md
  - docs/specs/companions/recommend-mode.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# Session 内部状態: Kit

`kit` Tool の Session は `KitSessionState` (`@Observable`) として状態を保持する。
**ペイン移動で状態が失われない** ことを保証する。

Tool 仕様 (UI / 操作) は [../tools/kit.md](../tools/kit.md) を参照。
共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `expandedSections` | `Set<KitSection>` | 展開中のセクション (`.agents` / `.skills` / `.commands` / `.mcps`) | ✅ |
| `expandedGroups` | `Set<String>` | Skills/Commands のサブグループ展開状態 | ✅ |
| `selection` | `String?` | 選択中の項目 ID | ✅ |
| `isActive` | `Bool` | アクティブ状態フラグ | ✅ |

## 内部ローダ

4 種のローダを束ねる (`Services/Kit/` 配下):

| ローダ | 対象 |
|---|---|
| `AgentsLoader` | `~/.claude/agents/*.md` + `<projectRoot>/.claude/agents/*.md` |
| `SkillsLoader` | `~/.claude/skills/*/SKILL.md` + `<projectRoot>/.claude/skills/*/SKILL.md` |
| `CommandsLoader` | `~/.claude/commands/*.md` + `<projectRoot>/.claude/commands/*.md` |
| `McpLoader` | `~/.claude.json` の `mcpServers` |

## 自動更新 (FileWatcher)

Kit は Window singleton で、`KitSessionState` が `FileWatcher` を 1 つ保持する。外部エディタ等で `.claude/` 配下に変更が発生したら自動的に `reloadAll()` を実行する。Tool 仕様は [../tools/kit.md#自動更新](../tools/kit.md#自動更新) を参照。

| プロパティ | 型 | 用途 | 永続化 |
|---|---|---|---|
| `watcher` | `FileWatcher` | `~/.claude/` と `<projectRoot>/.claude/` を監視 | — |
| `reloadDebounce` | `DispatchWorkItem?` | 変更通知のデバウンス (200ms) | — |

### ライフサイクル

| イベント | アクション |
|---|---|
| Session 生成時 | `watcher.start(paths: [~/.claude, <projectRoot>/.claude])` |
| `projectRoot` 変更時 | watcher を stop → 新しい projectRoot で再 start |
| 変更通知 (FSEvents コールバック) | 200ms デバウンス後に `reloadAll()` |
| Session 破棄時 | `watcher.stop()` |

## 永続化

`expandedSections` と `expandedGroups` は `<projectRoot>/.aidea/workspace.json` に保存される。
詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `currentScene()` | 場面 |
|---|---|
| `"kit"` | Kit ツール全体 (選択中セクションで分岐しない) |

- 将来的に `selection` (選択中の項目 ID) やセクション (`agents` / `skills` / `commands` / `mcps`) で分岐させる余地あり。現時点では単一 Scene `"kit"` で開始する。
- 初期プロンプトは空配列 (`[]`)、`defaultCompanionIndex` は `0`。
