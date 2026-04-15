# Session 内部状態: Kit

`kit` Tool の Session は `KitSessionState` (`@Observable`) として状態を保持する。
**ペイン移動で状態が失われない** ことを保証する。

Tool 仕様 (UI / 操作 / 受け入れ基準) は [../tools/kit.md](../tools/kit.md) を参照。
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

## 永続化

`expandedSections` と `expandedGroups` は `<projectRoot>/.aidea/workspace.json` に保存される。
詳細は [../persistence.md](../persistence.md) を参照。
