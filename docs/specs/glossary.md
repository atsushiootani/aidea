---
title: Glossary
description: Aidea プロジェクトで使われる用語 (Window/Pane/Tab/Session/Tool/SessionID/Companion 等) の定義
derived_from: []
syncs_with:
  - docs/specs/sessions/session.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-22
---

# Glossary

Aidea プロジェクトで使われる用語の定義。

## プロジェクト

| 用語 | 意味 |
|---|---|
| **Aidea** | 本プロジェクト名。**AI + IDE + Idea** のトリプルミーニング |
| **MVP** | Minimum Viable Product。最低限動く機能セット。MVP スコープの管理は GitHub Milestones / Issues で行う |
| **Vibeyard 問題** | `<webview>` / iframe 制約により本物のブラウザ挙動が得られない現象。Aidea が自作される動機 |

## UI 階層 (5 階層モデル)

| 用語 | 意味 |
|---|---|
| **Window** | アプリの 1 ウィンドウ。Aidea は 1 Window = 1 プロジェクト |
| **Pane** | Window 内の物理的な区画。`LayoutConfig` の `splitLeaf` / `removeLeaf` により動的に分割・削除される。境界をドラッグでリサイズ可 |
| **Tab** | ペイン内の表示切替単位。1 つの Session を参照する。タブヘッダに表示される |
| **TabSlot** | タブバー上の挿入位置。タブとタブの間、および両端に配置される。タブが N 個あるとき TabSlot は N+1 個存在し、Session の移動/並び替え (SessionID ドロップ) に加え、Filer / Finder からファイルをドロップすると **その位置に Preview Session が新規作成**される drop destination。ホバー時にアクセントカラーの縦線で可視化 |
| **Session** | 1 つの実体。Window 全体で一意の `SessionID` を持ち、独立した状態 (`SessionState`) を保持する。ペイン移動で状態は失われない |
| **Tool** | 機能の種別を表す enum (`filer` / `kit` / `terminal` / `claude` / `web` / `preview` / `git` / `gitDiff`)。Tool そのものは状態を持たない。複数の Session が同じ Tool を共有しうる |

## Session 関連

| 用語 | 意味 |
|---|---|
| **SessionID** | `(tool: Tool, instance: Int)` の組。Window 内で一意 |
| **SessionState** | Session の内部状態。Tool ごとに 1 種類定義され、ペイン移動を超えて維持される |
| **SessionRegistry** | Window 全体で Session 実体を管理するレジストリ。`activeSessionID` と `activeSessionHistory` も保持 |
| **Active Session** | Window 全体で常に 1 つ存在する "現在操作中の Session"。青ハイライトされる |
| **activeSessionHistory** | `activeSessionID` の変更履歴 (末尾が最新、重複排除済、最大 50 件)。Preview 開く先のペインを決める / [Active Session Switcher](./window/active-session-switcher.md) の表示元 / Tab クローズで該当 ID を除去 |

## Tool 種別

| ID | 内容 | 制約 |
|---|---|---|
| `filer` | ファイラ (NSOutlineView ベース) | **シングルトン** (Window 全体で 1 つだけ) |
| `kit` | Claude Code エコシステムの装備品一式 (Agents / Skills / Commands / MCPs) を 1 つのペインに束ねた Tool | **シングルトン** (Window 全体で 1 つだけ) |
| `terminal` | SwiftTerm ベースの PTY ターミナル | — |
| `claude` | Claude CLI を自動起動するターミナル + Backchannel 連携 (コンパニオンが紐付く) | — |
| `web` | WKWebView ベースの Web ブラウザ | — |
| `preview` | ファイルプレビュー。テキストは NSTextView、画像は NSImage、drawio は WebView | — |
| `git` | ステージ/コミット/ブランチ UI | **シングルトン** (Window 全体で 1 つだけ) |
| `gitDiff` | Git ツールから開く差分ビュー (diff2html) | `+` メニューからは追加不可、Git ツール経由で開く |

## アーキテクチャ用語

| 用語 | 意味 |
|---|---|
| **WorkspaceState** | Window 全体で共有される状態。`projectRoot` を持つ |
| **LayoutConfig** | 4 ペインの Pane 配列と、新規 Session インスタンス番号の採番を行う |
| **ProjectRoot** | 現在開いているプロジェクトのルートディレクトリ。`UserDefaults` に永続化される |
| **Tool (種別)** vs **Session (実体)** vs **Tab (表示)** | 同じ Tool の Session が複数作れる。同じ Session は複数の Tab で参照可能 (実質的にはペイン移動で同一 Session を別 Pane に表示することに相当) |

## 環境 / ファイル

| 用語 | 意味 |
|---|---|
| **USER スコープ** | `~/.claude/` 配下のリソース (Skill/Command)。UI でグレーの USER バッジ |
| **PROJECT スコープ** | `<projectRoot>/.claude/` 配下のリソース。UI で青の PROJECT バッジ |
| **frontmatter** | Markdown ファイル先頭の `---` で囲まれた YAML 風メタデータ |

## 関連

- [architecture.md](./architecture.md) — 技術スタックとコード構造
- [sessions/ui-rules.md#概念モデル](./sessions/ui-rules.md#概念モデル) — 5 概念の構造
- [decisions/](../decisions/README.md) — 設計判断の記録
