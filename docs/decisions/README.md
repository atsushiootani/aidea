# Architecture Decision Records

Aidea の設計判断を 1 件ずつ記録する。フォーマットは [Michael Nygard 形式](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) を踏襲。

## 一覧

| # | タイトル | 状態 |
|---|---|---|
| [0001](./0001-swift-swiftui.md) | Electron ではなく Swift/SwiftUI を採用 | 採用 |
| [0002](./0002-no-code-editor.md) | コードエディタ機能を持たない | 採用 |
| [0003](./0003-claude-api-direct.md) | Claude API を直接叩く（Claude Code CLI は別途使う） | 採用 |
| [0004](./0004-git-diff-with-diff2html.md) | Git diff は WebView + diff2html で表示 | 暫定 |
| [0005](./0005-obsidian-hybrid.md) | Obsidian 連携は URL スキーム + 直接ファイル操作のハイブリッド | 採用 |
| [0006](./0006-only-swiftterm-dependency.md) | 外部依存は SwiftTerm のみに絞る | 採用 |
| [0007](./0007-name-aidea.md) | プロジェクト名は Aidea | 確定 |
| [0008](./0008-no-claude-autostart.md) | ターミナルでは claude を自動起動しない | 採用 |
| [0009](./0009-nsoutlineview-and-fsevents.md) | ファイラは NSOutlineView + FSEvents で実装する | 採用 |
| [0010](./0010-drawio-rendering-paths.md) | drawio ファイルの描画は形式ごとに異なる経路を使う | 採用 |

## 新規追加方法

1. 既存の最大番号 + 1 でファイル作成 (`NNNN-kebab-title.md`)
2. 状態欄: `提案 / 採用 / 暫定 / 廃止 / 置換 (→ NNNN)`
3. この README の表に行を追加
