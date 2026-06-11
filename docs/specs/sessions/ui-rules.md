---
title: Session UI ルール
description: 5 概念モデル (Window/Pane/Tab/Session/Tool)・シングルトン制約・右クリック・選択フォーカス・Emacs ナビなど Session 共通 UI 仕様
derived_from:
  - docs/decisions/0013-session-as-first-class-object.md
  - docs/decisions/0014-no-ctrl-number-shortcuts.md
syncs_with:
  - docs/specs/sessions/session.md
  - docs/specs/aspects/view-hierarchy.md
impacts:
  - docs/specs/tools/*
  - docs/specs/sessions/*
  - docs/specs/companions/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-21
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

### タブのリネーム

タブヘッダを **ダブルクリック** すると、タブ名をその場で編集できる (全 Tool 共通)。

- ダブルクリックでラベルがインライン TextField に切り替わる (現在の表示名がプリセットされる)
- **Enter** で確定 / **Esc** でキャンセル / フォーカス喪失で確定
- **空文字 (空白のみ含む) で確定するとカスタム名を解除** し、デフォルトの導出名
  (Preview のタイトル / Web の URL / Claude のコンパニオン名 / tool 名) に戻る
- カスタム名は `displayLabel` の **最優先**。Web タブの URL 追従 ([../tools/web.md#タブ名](../tools/web.md#タブ名))
  よりもカスタム名が優先される
- 保存先は `SessionRegistry.customTitles: [SessionID: String]`。タブクローズ (destroySession) で破棄する
- `workspace.json` に永続化され、再起動後も保持される ([../aspects/persistence.md](../aspects/persistence.md))
- 1 クリック目のタブアクティブ化は従来通り即時発火する (ダブルクリックの 1 打目でアクティブ化、
  2 打目で編集開始)

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

`EmacsNavigation` ヘルパを使い、NSOutlineView / NSTableView サブクラスの `keyDown` 処理に統合する。SwiftUI 主体の Session も同等のショートカットを提供する。

---

## 背景色

**Session / Window / 補助 UI の背景は、明示的な指定がない限りガラス効果 (半透明) を使わない。**
不透明な固定色を既定とする。リスト / ツリー / エディタ / ヘッダなど、種別を問わず同じ原則を適用する。

### 理由

半透明背景は下のレイヤ (ウィンドウ背景 / デスクトップ画像 / 隣接ペイン) の色に応じて印象が変わり、
テキスト色 (ファイル名の青、Git ステータスの緑 / 赤など) とのコントラストが崩れて読みにくくなる。
背景色を固定すれば、配色の見通しが保てて、アクセシビリティも確保しやすい。

### 実装ルール (AppKit / NSOutlineView 系)

- `NSScrollView.drawsBackground = true` で不透明背景を描画する
- `NSOutlineView.style` は `.plain` を使う (`.sourceList` は半透明サイドバー背景を強制するため、明示的な例外指定がない限り使わない)
- `NSVisualEffectView` を追加しない
- 背景色は `NSColor.controlBackgroundColor` を基本とする

### 実装ルール (SwiftUI)

- 必要に応じて `.background(Color(nsColor: .windowBackgroundColor))` 等で不透明色を明示する
- `.background(.ultraThinMaterial)` / `.regularMaterial` / `.thickMaterial` などのガラス系マテリアルは、
  この spec に例外として明記された箇所でのみ使用する

### ガラスを使う明示的な例外

明示的な意図がある場合に限り、ガラス効果を許容する。例外はこの spec または個別の Tool spec に
理由と場所を記載すること。

| 箇所 | 理由 | 参照 |
|---|---|---|
| (現時点で規約化された例外はない) | — | — |
