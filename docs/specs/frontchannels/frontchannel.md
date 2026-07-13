---
title: Frontchannel 仕様
description: Aidea がコンパニオン (Claude セッション) にプロンプトを送信する PTY 送信メカニズム
derived_from: []
syncs_with: []
impacts:
  - docs/specs/frontchannels/scene.md
  - docs/specs/companions/companion.md
  - docs/specs/companions/recommend-mode.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# Frontchannel 仕様

> Aidea からコンパニオン（Claude セッション）にプロンプトを送信する仕組み

Backchannel（Claude → Aidea、ファイル経由）の逆方向。
PTY への書き込みで Claude セッションに直接プロンプトを送る。

---

## チャネルの全体像

| 方向 | 名前 | 手段 |
|------|------|------|
| Claude → Aidea | [Backchannel](../backchannels/backchannel.md) | ファイル書き出し (`.aidea/backchannels/`) |
| Aidea → Claude | **Frontchannel** | PTY への書き込み |

---

## 送信メカニズム

PTY へキャラクタを書き込む経路でプロンプトを送る。ユーザーがキーボードで打ったのと同等。

- Claude CLI は `\r` (CR) で送信を受け付ける
- 本文と `\r` は**分離して送る** (本文送信 → ≈0.3s 後に `\r`)。Claude Code (Ink 製 TUI) は bracketed paste を有効にしており、両者を一度に送ると `\r` も paste の一部とみなされ submit されないため
- セッションが未起動の場合は自動起動し、[受付可能](../tools/claude.md#起動フロー)になるのを待ってから送信する (**受付可能になってから送る送信**)。受付可能前の送信は保留され、受付可能になった時点で順に送られる

---

## 境界

### Always
- メッセージ送信は PTY への書き込み経由で行う
- 未起動のコンパニオンにメッセージを送る場合は自動起動する
- メッセージ送信後、対象の Claude セッションをアクティブタブにする

### Never
- メッセージ内容をアプリ側で加工・変換しない（ユーザーの意図をそのまま Claude に伝える）

---

## 関連ドキュメント

- [../companions/companion.md](../companions/companion.md) — 送信の起点となるコンパニオン UI とストア
- [../companions/recommend-mode.md](../companions/recommend-mode.md) — Cmd+Enter によるレコメンド選択 UI
- [scene.md](./scene.md) — レコメンドを解決する Scene キー
- [voice-input.md](./voice-input.md) — 音声入力ダイアログからの送信経路
