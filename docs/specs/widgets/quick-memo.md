---
title: クイックメモ
description: Cmd+M で即座に開く浮動メモパネル。入力テキストを <projectRoot>/quickmemo/todo/ にタイムスタンプ付きで保存する
derived_from: []
syncs_with:
  - docs/specs/aspects/keybindings.md
  - docs/specs/aspects/persistence.md
  - docs/specs/window/shortcuts.md
  - docs/specs/aspects/view-hierarchy.md
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/widgets/README.md
last_updated: 2026-05-05
---

# クイックメモ

`AppHeaderView` の `WidgetView` に常駐するクイックメモ機能。
**Cmd+M** またはヘッダ右端のボタンを押すと入力パネルが開き、メモを保存すると
`<projectRoot>/quickmemo/todo/<timestamp>.md` に書き出される。

GitHub Issue: [#5](https://github.com/atsushiootani/aidea/issues/5)

## UI 配置

`WidgetView` の中で `TimerView` の左隣にボタンを追加する。

```
AppHeaderView
└─ HStack(spacing: 8)
   ├─ CompanionView          ※既存
   ├─ speechToggleButton     ※既存
   ├─ Spacer                 ※既存
   └─ WidgetView             ※既存
      ├─ QuickMemoButton     ★新規 (メモアイコンボタン + popover)
      └─ TimerView           ※既存
```

### QuickMemoButton

- `square.and.pencil` システムアイコンのシンプルなボタン
- 押すと `.popover` が開き、`QuickMemoView` を表示する
- パネルが開いている間はアイコンをアクセントカラーで強調
- `.help("クイックメモ (⌘ M)")` でツールチップを表示する

### QuickMemoView (popover 内容)

```
┌─ クイックメモ ──────────────────────────────┐
│                                             │
│  ╔══════════════════════════════════════╗  │
│  ║                                      ║  │
│  ║  (TextEditor  280×140pt)             ║  │
│  ║                                      ║  │
│  ╚══════════════════════════════════════╝  │
│                                             │
│                    [キャンセル]  [保存]      │
└─────────────────────────────────────────────┘
```

| 要素 | 説明 |
|---|---|
| タイトル | 「クイックメモ」ラベル |
| TextEditor | 自由入力。フォーカス自動取得 |
| キャンセルボタン | Esc または押下で内容を破棄してパネルを閉じる |
| 保存ボタン | Cmd+Return または押下で保存してパネルを閉じる。入力が空なら無効 |

## ショートカット

| キー | 動作 |
|---|---|
| **⌘ M** | クイックメモパネルを開く (パネルが開いていれば閉じる) |
| **⌘ Return** | パネル内: 保存して閉じる |
| **Esc** | パネル内: 破棄して閉じる |

`AideaApp.registerKeyEventMonitor()` に Cmd+M ハンドラを追加してイベントを吸収する
(macOS 標準の「ウィンドウを最小化」Cmd+M より前に処理するため)。

## 状態モデル

```
@Observable
final class QuickMemoState {
    var isPresented: Bool   // パネル表示中
    var draftText: String   // 編集中のテキスト

    func present()          // パネルを開く (draftText をクリア)
    func save(to:)          // ファイル書き出し → dismiss
    func dismiss()          // パネルを閉じる (draftText をクリア)
}
```

- `QuickMemoState` は `AideaApp` レベルで 1 インスタンスを保持し、`@Environment` で配布する
- 永続化はしない (アプリ再起動で常に `isPresented=false / draftText=""`)

## 保存先

```
<projectRoot>/
└─ quickmemo/
   └─ todo/
      ├─ 2026-05-05-143000.md   ← タイムスタンプ付きファイル
      └─ ...
```

- ファイル名: `YYYY-MM-DD-HHmmss.md` 形式のタイムスタンプ
- ファイル内容: 入力テキストをそのまま UTF-8 で書き出す
- ディレクトリが存在しない場合は自動生成する
- `quickmemo/` は `.aidea/` とは別の場所に置き、**git 管理対象とする** (`.gitignore` には追加しない)
- 空白のみのテキストは保存せず破棄する

## 永続化

`QuickMemoState` は**永続化しない** (アプリ再起動で常に初期状態に戻る)。
保存済みのメモファイル (`quickmemo/todo/*.md`) はプロジェクトリポジトリに蓄積される。

## 境界

- **Always**: Cmd+M のキーイベントはシステムの minimize より前に吸収する
- **Always**: 保存時は `draftText` を trim し、空なら保存しない
- **Always**: `QuickMemoButton` は `WidgetView` の中の `TimerView` より左に置く
- **Never**: `quickmemo/` を `.aidea/` 配下に置かない (プロジェクトデータとして git 管理したいため)
- **Never**: `workspace.json` に draftText を書き込まない

## 関連

- [../aspects/keybindings.md](../aspects/keybindings.md) — ⌘ M を追加
- [../aspects/persistence.md](../aspects/persistence.md) — quickmemo/todo/ のパス定義
- [../window/shortcuts.md](../window/shortcuts.md) — グローバルショートカット (⌘ M)
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — QuickMemoButton の配置
- [README.md](./README.md) — Widgets カテゴリ全体
