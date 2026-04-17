---
title: Session UI ルール
description: 5 概念モデル (Window/Pane/Tab/Session/Tool)・シングルトン制約・右クリック・選択フォーカス・Emacs ナビなど Session 共通 UI 仕様
derived_from:
  - docs/decisions/0013-session-as-first-class-object.md
  - docs/decisions/0014-no-ctrl-number-shortcuts.md
syncs_with: []
impacts:
  - docs/specs/tools/*
  - docs/specs/sessions/*
  - docs/specs/companions/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
---

# Session UI ルール

各 Session が守るべき UI 振る舞い仕様。
個別の Tool 仕様 (`../tools/*.md`) はこのルールを前提にして記述する。

Window 全体のルールは [../window/](../window/README.md) を参照。

---

## 概念モデル

Aidea の UI は **Window / Pane / Tab / Session / Tool** という 5 つの概念で構成される。

```
Window
 └─ Pane (リサイズ可能な物理区画。HSplitView/VSplitView でツリー状)
     └─ Tab (ペイン内の表示切替単位。1 つの Session を参照する)
         └─ Session (1 つの実体。Window 全体で一意。状態を持つ)
              └─ Tool (機能種別。複数の Session が同じ Tool を共有しうる)
```

用語の定義は [../glossary.md](../glossary.md) を参照。
アクティブ Session の切替・履歴・Filer ダブルクリック時の挙動は [active-session.md](./active-session.md) を参照。
各 Tool の `SessionState` 実装は本ディレクトリの per-tool ファイル ([filer.md](./filer.md) / [kit.md](./kit.md) / [terminal.md](./terminal.md) / [claude.md](./claude.md) / [web.md](./web.md) / [preview.md](./preview.md) / [git.md](./git.md) / [git-diff.md](./git-diff.md)) を参照。

### シングルトン制約

以下の Tool は Window 全体で **1 つだけ** に制限される (`PaneView` の `+` メニューで条件付き非表示)。

- **`filer`** — ファイラは Window につき 1 つ
- **`git`** — Git ツールも Window につき 1 つ

`gitDiff` は `+` メニューに載らず、Git ツール経由で開く。
その他の Tool (`kit` / `terminal` / `claude` / `web` / `preview`) は同一 Window 内に複数インスタンス可。

---

## 右クリック・コンテキストメニュー

- **各 Session は、そのツールの主要機能を右クリックで呼び出せるようにする**
  - NSOutlineView など AppKit を直接使う Session は `menu(for:)` をオーバーライド
  - SwiftUI 主体の Session は `.contextMenu` モディファイアを使う
- **右クリック位置の項目が未選択なら、まずその項目を選択してからメニューを表示する**
- メニュー項目はキーボードショートカットと 1:1 で対応させ、メニュー項目のタイトルに同じショートカット (`⏎` `⌘N` `⌫` 等) を併記する
- メニュー項目の有効/無効は現在の選択状態に応じて切り替える (`NSMenu.autoenablesItems = false` + 明示的な `isEnabled`)

---

## 選択・フォーカス

- **複数選択を許可する Session** では Shift+クリック / Shift+↑↓ を NSOutlineView / SwiftUI List の標準動作に任せる
- フィルタ/検索/並び替えによる reloadData 後は、事前の選択状態を可能な限り復元する

新規作成・リネーム・移動など **別のノードにフォーカスすべき操作後の再フォーカス規則** は各 Tool 仕様 (`../tools/*.md`) に記述する。

---

## キーボードナビゲーション (Emacs ライク)

リスト/ツリーを扱うすべての Session は、以下のキーバインディングを必ずサポートする。

| キー | 動作 | マップ先 |
|---|---|---|
| **Ctrl + P** | 上へ移動 | `moveUp` |
| **Ctrl + N** | 下へ移動 | `moveDown` |
| **Ctrl + F** | 右へ移動 | `moveRight` |
| **Ctrl + B** | 左へ移動 | `moveLeft` |
| **Ctrl + V** | ページダウン | `pageDown` |
| **Ctrl + Z** | ページアップ | `pageUp` |

実装は `Aidea/Utilities/EmacsNavigation.swift` の `EmacsNavigation.handle(event:responder:)` を使う。
NSOutlineView / NSTableView サブクラスは `keyDown(with:)` 内で以下のように呼び出す:

```swift
if EmacsNavigation.handle(event: event, responder: self) { return }
```

SwiftUI 主体の Session も同等のショートカットを提供する (将来 `onKeyPress` で実装)。
