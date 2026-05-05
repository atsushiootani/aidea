---
title: Session 内部状態: Kit
description: Kit Tool の状態 (expandedSections / expandedGroups / selection) と 4 種ローダ・ファイル監視による自動更新・workspace.json 永続化・Scene とレコメンドプロンプト
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
last_updated: 2026-05-05
---

# Session 内部状態: Kit

`kit` Tool の Session 状態を管理する。4 種のリソースローダーと展開・選択状態を保持する。
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

4 種のローダを束ねる:

| ローダ | 対象 |
|---|---|
| エージェントローダ | `~/.claude/agents/*.md` + `<projectRoot>/.claude/agents/*.md` |
| スキルローダ | `~/.claude/skills/*/SKILL.md` + `<projectRoot>/.claude/skills/*/SKILL.md` |
| コマンドローダ | `~/.claude/commands/*.md` + `<projectRoot>/.claude/commands/*.md` |
| MCP ローダ | `~/.claude.json` の `mcpServers` |

## 自動更新 (ファイル監視)

Kit は Window singleton で、Kit Session がファイル監視コンポーネントを 1 つ保持する。外部エディタ等で `.claude/` 配下に変更が発生したら自動的に全ローダを再実行する。Tool 仕様は [../tools/kit.md#自動更新](../tools/kit.md#自動更新) を参照。

| 役割 | 内容 |
|---|---|
| 監視対象 | `~/.claude/` と `<projectRoot>/.claude/` |
| デバウンス | 変更通知から 200ms 待って再読み込み実行 |

### ライフサイクル

| イベント | アクション |
|---|---|
| Session 生成時 | `~/.claude/` と `<projectRoot>/.claude/` の監視を開始 |
| `projectRoot` 変更時 | 監視を停止 → 新しい projectRoot で再開 |
| 変更通知 (FSEvents コールバック) | 200ms デバウンス後に全ローダを再実行 |
| Session 破棄時 | 監視を停止 |

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
