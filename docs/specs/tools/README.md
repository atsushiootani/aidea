---
title: Tools (各ツール仕様) インデックス
description: Aidea の各 Tool (Claude / Filer / Git / Kit / Obsidian / Preview / Terminal / Web) 仕様ファイルのインデックス
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts:
  - docs/specs/tools/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# Tools (各ツール仕様) インデックス

Aidea の Tool (Pane に表示される機能単位) ごとの仕様ファイルを集約する。
Tool / Pane / Tab / Session / Window の概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。

## ファイル一覧

| ファイル | 内容 | 備考 |
|---|---|---|
| [claude.md](./claude.md) | Claude Code 自動起動 + Backchannel 連携ターミナル | 複数可 |
| [filer.md](./filer.md) | NSOutlineView ベースのファイルツリー | シングルトン |
| [git.md](./git.md) | Git 差分表示 (Working Changes / PR Preview) と GitDiff | Git シングルトン / GitDiff 複数可 |
| [kit.md](./kit.md) | Skills / Commands / Agents / MCPs を 1 ペインで閲覧 | シングルトン |
| [obsidian.md](./obsidian.md) | Obsidian vault 連携 | **MVP 未実装** |
| [preview.md](./preview.md) | ファイルプレビュー (Markdown / 画像 / drawio / テキスト) | 複数可 |
| [terminal.md](./terminal.md) | SwiftTerm ベースの PTY ターミナル | 複数可 |
| [web.md](./web.md) | WKWebView ベースのブラウザ (ツールバー / URL クリックルーティング / JS ダイアログ) | 複数可 |

## 共通規約

- **概念モデル・UI ルール**: [sessions/ui-rules.md](../sessions/ui-rules.md)
- **グローバルショートカット・ダイアログ規約**: [window/](../window/README.md)
- **キー操作・マウス操作の横断一覧**: [aspects/keybindings.md](../aspects/keybindings.md)
- **Session 内部状態**: [sessions/](../sessions/README.md) 配下の同名ファイル (例: `tools/claude.md` ↔ `sessions/claude.md`)

## 更新ルール

- 各 Tool の仕様を変更したら、対応する [sessions/](../sessions/) 配下のファイルと [aspects/keybindings.md](../aspects/keybindings.md) の該当セクションも同時に更新する (`syncs_with` 関係)
- 新しい Tool を追加したら本ファイル一覧表にも行を追加する
