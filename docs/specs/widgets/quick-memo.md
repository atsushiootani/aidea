---
title: クイックメモ
description: Cmd+M でヘッダ右端のボタンから即座にメモ入力 popover を開き、quickmemo/todo/ 配下に Markdown ファイルとして保存する Widget 仕様
derived_from: []
syncs_with:
  - docs/specs/aspects/keybindings.md
  - docs/specs/aspects/persistence.md
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/window/shortcuts.md
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/widgets/README.md
last_updated: 2026-05-06
---

# クイックメモ

Aidea ヘッダ右端の ✏️ ボタン (または Cmd+M) で即座にメモ入力用 popover を開き、
入力したテキストを `<projectRoot>/quickmemo/todo/` 配下に Markdown ファイルとして保存する Widget。

---

## 概要

| 項目 | 内容 |
|---|---|
| 起動ショートカット | **Cmd+M** |
| UI 形式 | ✏️ ボタン押下 (または Cmd+M) で popover 表示 |
| 保存先 | `<projectRoot>/quickmemo/todo/<timestamp>.md` |
| 空メモの扱い | 空白のみは保存せず破棄。保存ボタンを無効化 |

---

## UI 仕様

### ヘッダへの配置

`WidgetView` の `HStack` 内に `QuickMemoButton` を追加する。
`TimerView` (ポモドーロ) の左隣に配置する。

```
WidgetView
└─ HStack
   ├─ QuickMemoButton  ← 今回追加 (✏️ アイコン)
   ├─ TimerView        (ポモドーロ)
   └─ FocusTimerView   (没入防止タイマー)
```

### Popover 内レイアウト

```
┌─ QuickMemoView ──────────────────┐
│  TextEditor (複数行)               │
│  (プレースホルダ: "メモを入力...")  │
│                                   │
│  [キャンセル]         [保存]        │
└────────────────────────────────────┘
```

- 幅: 300pt 固定
- TextEditor の高さ: 120pt 固定
- ボタン配置: 下部右寄せ。キャンセルが左、保存が右
- 保存ボタン: テキストが空白のみのとき disabled

### キー操作

| キー | 動作 |
|---|---|
| **Cmd+M** | popover を開く / 閉じる (トグル) |
| **Cmd+Return** | 保存して閉じる (空白のみ時は無効) |
| **Esc** | キャンセルして閉じる |

---

## ファイル保存仕様

### 保存先

```
<projectRoot>/quickmemo/todo/<timestamp>.md
```

- `<timestamp>` のフォーマット: `yyyy-MM-dd_HHmmss`
- 例: `2026-05-06_143022.md`
- `quickmemo/todo/` ディレクトリが存在しない場合は自動生成する

### ファイル内容

入力されたテキストをそのまま Markdown ファイルとして書き出す。
メタデータ (タイムスタンプ・タイトル等) は付加しない。

### 保存タイミング

「保存」ボタン押下または Cmd+Return 時に即時書き出す。
失敗した場合はファイルを作成せず、popover はそのまま閉じない (ユーザに問題が伝わるよう保持する)。

---

## 状態管理

- `isPresented: Bool` — popover の表示状態
- `memoText: String` — 入力中のテキスト

popover を閉じた後 (保存・キャンセル共通) に `memoText` を空文字にリセットする。

---

## 永続化

クイックメモ自体の状態 (開閉・入力中テキスト) は**永続化しない**。
アプリ再起動で常に「未入力・閉じた状態」から開始する。

保存済みファイル (`quickmemo/todo/*.md`) はプロジェクトルートに保存するが、
`.aidea/` 配下ではないため `.aidea/.gitignore` の対象外。
ユーザのプロジェクト側 `.gitignore` で管理を決める。

---

## 関連ドキュメント

- [README.md](./README.md) — Widgets インデックス
- [../aspects/keybindings.md](../aspects/keybindings.md) — グローバルキー一覧
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — View 親子関係
- [../window/shortcuts.md](../window/shortcuts.md) — グローバルショートカット
