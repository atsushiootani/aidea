---
title: キー操作・マウス操作一覧
description: 全キーボードショートカットとマウス操作を機能群横断で集約したリファレンス
derived_from:
  - docs/decisions/0014-no-ctrl-number-shortcuts.md
  - docs/decisions/0016-terminal-mouse-event-suppression.md
  - docs/decisions/0017-alternate-screen-scroll-handling.md
syncs_with:
  - docs/specs/tools/claude.md
  - docs/specs/tools/filer.md
  - docs/specs/tools/git.md
  - docs/specs/tools/kit.md
  - docs/specs/tools/preview.md
  - docs/specs/tools/terminal.md
  - docs/specs/tools/web.md
  - docs/specs/window/shortcuts.md
  - docs/specs/companions/recommend-mode.md
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/aspects/README.md
last_updated: 2026-04-20
---

# キー操作・マウス操作一覧

Aidea の全キーボードショートカットとマウス操作のリファレンス。
各ツール固有の詳細は `tools/*.md` を参照。

---

## グローバル（どのビューでも有効）

### タブ・ペイン操作

| キー | アクション |
|------|-----------|
| ⌘ T | 新しいタブを追加（Tool 選択ダイアログ） |
| ⌘ W | 現在のタブを閉じる |
| ⌘ ⇧ [ | 現在ペイン内で左のタブへ（ラップ） |
| ⌘ ⇧ ] | 現在ペイン内で右のタブへ（ラップ） |
| ⌘ [ | 前のペインへ（ラップ） |
| ⌘ ] | 次のペインへ（ラップ） |
| ⌘ ⌥ → | 現在のペインを左右に分割 |
| ⌘ ⌥ ↓ | 現在のペインを上下に分割 |

### ツール切替

| キー | Tool |
|------|------|
| ⌘ ⌥ 1 | Filer |
| ⌘ ⌥ 2 | Kit |
| ⌘ ⌥ 3 | Git |
| ⌘ ⌥ 7 | Terminal |
| ⌘ ⌥ 8 | Claude |
| ⌘ ⌥ 9 | Web |
| ⌘ ⌥ 0 | Preview |

### コンパニオン

| キー | アクション |
|------|-----------|
| ⌘ 1 〜 ⌘ 8 | 対応するコンパニオンを起動 / アクティブ化 |

### レコメンドモード

| キー | アクション |
|------|-----------|
| ⌘ Enter | レコメンドモードを開始 |
| ↑ / ↓ | プロンプトを選択 |
| ← / → | コンパニオンを選択（吹き出し移動） |
| Enter | 選択したプロンプトを送信 |
| Esc | キャンセル |

### その他

| キー | アクション |
|------|-----------|
| ⌘ O | ディレクトリを開く |

---

## Filer

### キーボード

| キー | アクション |
|------|-----------|
| Enter | ファイル → Preview で開く / ディレクトリ → 展開/折りたたみ |
| ⇧ Enter | 名前を変更 |
| ⌘ N | 新規ファイル |
| ⌘ ⇧ N | 新規ディレクトリ |
| Backspace | 削除（確認ダイアログ） |
| ⌘ F | 検索バーの表示/非表示 |
| Esc | 検索バーを閉じる |
| ⇧ ↑/↓ | 選択範囲を拡張 |
| Ctrl+P/N | Emacs 風上下移動 |
| Ctrl+F/B | Emacs 風左右移動 |

### マウス

| 操作 | アクション |
|------|-----------|
| クリック | 選択 |
| ⇧ クリック | 範囲選択 |
| ⌘ クリック | 選択追加/解除 |
| ダブルクリック（ファイル） | Preview で開く |
| ダブルクリック（ディレクトリ） | 展開/折りたたみ |
| ドラッグ&ドロップ | ファイル/ディレクトリの移動 |
| 右クリック | コンテキストメニュー |

---

## Kit

### キーボード

| キー | アクション |
|------|-----------|
| ↑ / ↓ | セクション横断の選択移動 |
| Enter | 選択アイテムを Preview で開く |

### マウス

| 操作 | アクション |
|------|-----------|
| クリック | 行選択 |
| ダブルクリック | Preview で開く |
| セクションヘッダクリック | 展開/折りたたみ |
| 右クリック | コンテキストメニュー |

---

## Git

### キーボード

| キー | アクション |
|------|-----------|
| ↑ / ↓ | ファイル選択の上下移動 |
| Enter | GitDiff を開く |
| Tab | GitDiff にフォーカス移動 |
| W | Working Changes モードに切替 |
| P | PR Preview モードに切替 |
| Ctrl+4 | Working Changes モードに切替（補助） |
| Ctrl+5 | PR Preview モードに切替（補助） |

### マウス

| 操作 | アクション |
|------|-----------|
| クリック | ファイル選択（GitDiff のスクロールも連動） |
| ダブルクリック | GitDiff を別ペインに開く |

---

## GitDiff

### キーボード

| キー | アクション |
|------|-----------|
| ↑ / ↓ | スクロール（端に到達で次/前のファイルにフォーカス移動） |
| ← / → | フォーカスファイルの水平スクロール |
| Space | フォーカスファイルの Viewed チェックボックスをトグル |
| Tab | Git ツールにフォーカス移動 |

### フォーカスファイル

- ビューポート中央のファイルが自動的にフォーカスファイルになる
- フォーカスファイルのヘッダ背景が青く着色される
- Git ツールの選択も連動して追従する

---

## Claude

### マウス（NSEvent モニターで変換）

| 操作 | 条件 | アクション |
|------|------|-----------|
| ホイールスクロール上 | トランスクリプトモード時 | Ctrl+U 送信（半ページ上） |
| ホイールスクロール下 | トランスクリプトモード時 | Ctrl+D 送信（半ページ下） |
| ホイールクリック | 常時 | Ctrl+O 送信（モードトグル） |

※ トランスクリプトモード = 最下行に `"transcript"` を含む状態（[ADR 0017](../decisions/0017-alternate-screen-scroll-handling.md)）
※ Terminal ツールでも同じマウス操作が有効（PersistentTerminalView 共用）

---

## Preview

### キーボード

| キー | アクション |
|------|-----------|
| Ctrl+P | 上スクロール |
| Ctrl+N | 下スクロール |
| Ctrl+F | 右スクロール |
| Ctrl+B | 左スクロール |
| Ctrl+V | ページ下スクロール |
| Ctrl+Z | ページ上スクロール |
| ⌘ E | drawio 編集モードトグル |
| Esc | drawio 編集キャンセル |

---

## 関連ドキュメント

- [../window/shortcuts.md](../window/shortcuts.md) — グローバルショートカット詳細
- [../tools/](../tools/) — 各ツールの仕様
- [../companions/recommend-mode.md](../companions/recommend-mode.md) — レコメンドモード詳細
- [ADR 0014](../decisions/0014-no-ctrl-number-shortcuts.md) — Ctrl+数字キー不採用の理由
- [ADR 0016](../decisions/0016-terminal-mouse-event-suppression.md) — mouseMoved 抑制
- [ADR 0017](../decisions/0017-alternate-screen-scroll-handling.md) — Alternate Screen スクロール変換
