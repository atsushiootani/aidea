---
title: クイックメモ
description: Cmd+M でヘッダ右端のボタンから即座にメモ入力 popover を開き、.aidea/widgets/quickmemo/memo.md に上書き保存する Widget 仕様
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
last_updated: 2026-05-29
---

# クイックメモ

Aidea ヘッダ右端の ✏️ ボタン (または Cmd+M) で即座にメモ入力用 popover を開き、
入力したテキストを `<projectRoot>/.aidea/widgets/quickmemo/memo.md` に**上書き保存**する Widget。

---

## 概要

| 項目 | 内容 |
|---|---|
| 起動ショートカット | **Cmd+M** |
| UI 形式 | ✏️ ボタン押下 (または Cmd+M) で popover 表示 |
| 保存先 | `<projectRoot>/.aidea/widgets/quickmemo/memo.md` (固定 1 ファイル) |
| 書き込み方式 | **上書き**。既存内容は失われる |
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
   └─ TimerView        (ポモドーロ)
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
<projectRoot>/.aidea/widgets/quickmemo/memo.md
```

- **固定 1 ファイル**。タイムスタンプは付けない。常に同じファイル名で上書き
- ファイル名は `memo.md` (kebab-case の慣行はあるが、ファイル名としては短く `memo.md`)
- `.aidea/widgets/quickmemo/` ディレクトリが存在しない場合は自動生成する
- `.aidea/` 配下のため Aidea が管理する `.git/info/exclude` (ローカル専用 ignore) でコミット対象から外れる

### ファイル内容

入力されたテキストをそのまま Markdown ファイルとして書き出す。
メタデータ (タイムスタンプ・タイトル等) は付加しない。

### 上書き運用

- 保存時に既存の `memo.md` の内容は **完全に置き換わる** (履歴は残らない)
- popover を開いた時に既存の `memo.md` を **読み込んで TextEditor に表示する** (前回の内容を継続編集できる)
- 同じファイルを継続的に育てる「**1 枚の付箋**」モデル

### popover オープン時の読込

- popover が表示されたタイミングで `.aidea/widgets/quickmemo/memo.md` を読み込んで `TextEditor` の初期テキストにする
- ファイルが存在しない場合は空欄から始める
- 読み込みに失敗した場合 (パーミッション等) も空欄で開く (popover 表示を妨げない)

### 保存タイミング

「保存」ボタン押下または Cmd+Return 時に **memo.md を現在の `memoText` で上書き**する。
失敗した場合はファイルを作成せず、popover はそのまま閉じない (ユーザに問題が伝わるよう保持する)。

### キャンセル時の挙動

- Esc / キャンセルボタンで popover を閉じた場合、**`memo.md` は変更しない**
- 編集途中の `memoText` は破棄される (次に開いた時はファイルの内容から再読込される)

---

## 状態管理

- `isPresented: Bool` — popover の表示状態
- `memoText: String` — 編集中のテキスト

popover を閉じた後 (保存・キャンセル共通) に `memoText` を空文字にリセットする。
次回 open 時にファイルから再読込されるため、メモリ上に内容を保持し続ける必要はない。

---

## 永続化

クイックメモの **入力中の状態** (popover の開閉・編集中テキスト) は**メモリ上のみ**で保持し、
アプリ再起動で常に「閉じた状態」から開始する。

**保存済みファイル** (`.aidea/widgets/quickmemo/memo.md`) は `.aidea/` 配下に置く。
ユーザの「**1 枚の付箋**」として永続化され、popover を開くたびに前回の内容が復元される。

`.aidea/` 全体は Aidea が `.git/info/exclude` (ローカル専用 ignore) に追記するため、
**共有 `.gitignore` の編集は不要**でリポジトリに混入しない (詳細: [../aspects/persistence.md](../aspects/persistence.md))。

`.aidea/widgets/` は **新カテゴリ**: 「ヘッダ Widget が永続化するユーザ編集可能なテキストファイル」を入れる。
今後 Widget が増えたら `.aidea/widgets/<widget-name>/` に並べる。

---

## 関連ドキュメント

- [README.md](./README.md) — Widgets インデックス
- [../aspects/keybindings.md](../aspects/keybindings.md) — グローバルキー一覧
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — View 親子関係
- [../window/shortcuts.md](../window/shortcuts.md) — グローバルショートカット
