---
title: Session 内部状態: Kit
description: Kit セッションが保持する状態 (セクション/グループの展開状態・選択) と 4 種ローダ・ファイル監視による自動更新・workspace.json 永続化・Scene とレコメンドプロンプト
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
last_updated: 2026-07-13
---

# Session 内部状態: Kit

`kit` Tool の Session が保持する状態。
**ペイン移動で状態が失われない** ことを保証する。

Tool 仕様 (UI / 操作) は [../tools/kit.md](../tools/kit.md) を参照。
共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| 状態 | 用途 | ペイン移動で保持 |
|---|---|---|
| 展開中セクション集合 | 展開中のセクション (Agents / Skills / Commands / MCPs) | ✅ |
| 展開中グループ集合 | Skills / Commands のサブグループ展開状態 | ✅ |
| 選択中項目 | 選択中の項目 ID | ✅ |
| アクティブフラグ | フォーカスバインド用のアクティブ状態フラグ | ✅ |

## 内部ローダ

4 種のローダを束ねる:

| ローダ | 対象 |
|---|---|
| Agents | `~/.claude/agents/*.md` + `<projectRoot>/.claude/agents/*.md` |
| Skills | `~/.claude/skills/*/SKILL.md` + `<projectRoot>/.claude/skills/*/SKILL.md` |
| Commands | `~/.claude/commands/*.md` + `<projectRoot>/.claude/commands/*.md` |
| MCPs | `~/.claude.json` の `mcpServers` |

## 自動更新

Kit は Window singleton で、Kit セッション状態がファイル監視 (FSEvents ベース) を 1 つ保持する。外部エディタ等で `.claude/` 配下に変更が発生したら自動的に全ローダを再読込する。Tool 仕様は [../tools/kit.md#自動更新](../tools/kit.md#自動更新) を参照。

| 状態 | 用途 | 永続化 |
|---|---|---|
| ファイル監視 | `~/.claude/` と `<projectRoot>/.claude/` を監視 | — |
| デバウンス | 変更通知を 200ms デバウンスしてから再読込 | — |

### ライフサイクル

| イベント | アクション |
|---|---|
| Session 生成時 | `~/.claude` と `<projectRoot>/.claude` の監視を開始 |
| プロジェクトルート変更時 | 監視を停止 → 新しいプロジェクトルートで再開 |
| 変更通知 (FSEvents コールバック) | 200ms デバウンス後に全ローダを再読込 |
| Session 破棄時 | 監視を停止 |

## 永続化

展開中セクション集合と展開中グループ集合は `<projectRoot>/.aidea/workspace.json` に保存される。
詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。

## Scene とレコメンドプロンプト

セッション共通の仕組み ([../frontchannels/scene.md](../frontchannels/scene.md)) で、Cmd+Enter のレコメンド送信に対応する。

| Scene 識別子 | 場面 |
|---|---|
| `"kit"` | Kit ツール全体 (選択中セクションで分岐しない) |

- 将来的に選択中の項目やセクション (agents / skills / commands / mcps) で分岐させる余地あり。現時点では単一 Scene `"kit"` で開始する。
- 初期プロンプトは空、既定の Companion は index 0。
