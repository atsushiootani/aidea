---
title: グローバルショートカット
description: Window 全体で有効なキーボードショートカット (タブ/ペイン操作・ツール切替・コンパニオン)
derived_from:
  - docs/decisions/0011-cmd-w-via-nsevent-monitor.md
  - docs/decisions/0014-no-ctrl-number-shortcuts.md
syncs_with:
  - docs/specs/aspects/keybindings.md
  - docs/specs/widgets/quick-memo.md
  - docs/specs/widgets/pomodoro.md
  - docs/specs/window/active-session-switcher.md
  - docs/specs/frontchannels/voice-input.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-17
---

# グローバルショートカット

Window 全体で有効なキーボードショートカット。
どの Tool にフォーカスしていても共通で効く。
`AideaApp.body.commands` の `CommandMenu("タブ")` / `CommandMenu("ツール")` / `CommandMenu("コンパニオン")` で実装する。

## タブ・ペイン操作

| キー | 動作 |
|---|---|
| **⌘ T** | 新しいタブを追加 (NSAlert ベースの Tool 選択ダイアログを開く) |
| **⌘ W** | 現在のタブを閉じる。全タブ消滅時はペインも削除 |
| **⌘ ⇧ [** | 現在ペイン内で左のタブへ (ラップ) |
| **⌘ ⇧ ]** | 現在ペイン内で右のタブへ (ラップ) |
| **⌘ [** | 前のペインへ (ラップ) |
| **⌘ ]** | 次のペインへ (ラップ) |
| **⌘ ⌥ →** | 現在のペインを左右に分割 |
| **⌘ ⌥ ↓** | 現在のペインを上下に分割 |
| **⌃ Tab** | Active Session Switcher 表示 / 履歴を古い方へ移動。Ctrl リリースで確定 (詳細: [active-session-switcher.md](./active-session-switcher.md)) |
| **⌃ ⇧ Tab** | Switcher 表示中、選択を新しい方へ移動 |

## ツール切替 (インスタンスの循環フォーカス)

現在アクティブ Session が同じ Tool なら **次のインスタンスに循環**、違う場合は最初のマッチに移動する。

| キー | Tool |
|---|---|
| **⌘ ⌥ 1** | Filer |
| **⌘ ⌥ 2** | Kit |
| **⌘ ⌥ 3** | Git |
| **⌘ ⌥ 7** | Terminal |
| **⌘ ⌥ 8** | Claude |
| **⌘ ⌥ 9** | Web |
| **⌘ ⌥ 0** | Preview |

## コンパニオン

| キー | 動作 |
|---|---|
| **⌘ 1** 〜 **⌘ 8** | 対応するコンパニオンを起動 / アクティブ化 |

## クイックメモ

`NSEvent.addLocalMonitorForEvents` で Cmd+M を横取りして popover をトグルする。詳細は [../widgets/quick-memo.md](../widgets/quick-memo.md)。

| キー | 動作 |
|---|---|
| **⌘ M** | クイックメモ popover を開く / 閉じる |

## ポモドーロ

`AideaApp.body.commands` の `CommandMenu("ポモドーロ")` で実装する。詳細は [../widgets/pomodoro.md](../widgets/pomodoro.md)。

| キー | 動作 |
|---|---|
| **⌘ ⌥ P** | ポモドーロタイマー 開始 / 一時停止 |
| **⌘ ⌥ ⇧ P** | ポモドーロタイマー リセット |

## 音声入力

`AideaApp.body.commands` の `CommandMenu("音声入力")` で実装する。詳細は [../frontchannels/voice-input.md](../frontchannels/voice-input.md)。

| キー | 動作 |
|---|---|
| **⌘ ⌥ V** | 音声入力ダイアログを開く (アクティブセッションが Claude のときのみ有効。それ以外は disabled) |

`AppHeaderView` のマイクボタン押下と完全に同じ起動経路を共有する (ダイアログ仕様 / マイク権限フロー / 送信先解決は voice-input.md を参照)。
