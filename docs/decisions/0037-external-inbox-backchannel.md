---
title: "0037: 外部からコンパニオンにメッセージを送る inbox backchannel を設ける"
description: .aidea/backchannels/inbox/ に外部スクリプトが JSON を書き出すと、Aidea が宛先 Companion を解決してプロンプトとして送信する外部入力チャネルを新設する。返信経路は持たない
status: 提案
derived_from:
  - docs/decisions/0023-companion-handoff.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
  - docs/decisions/0034-scheduler-snippet-dispatch.md
syncs_with:
  - docs/specs/backchannels/inbox.md
  - docs/specs/backchannels/backchannel.md
  - docs/specs/backchannels/README.md
  - docs/specs/aspects/persistence.md
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-01
---

# 0037: 外部からコンパニオンにメッセージを送る inbox backchannel を設ける

**日付**: 2026-07-01 / **issue**: #246

## 背景

外部プロセス (シェルスクリプト・cron・他アプリ等) から Aidea の Companion に
メッセージ (プロンプト) を送りたい、という要望がある (issue #246)。

既存の Backchannel はいずれも **Claude → Aidea** 方向、あるいは Aidea 内で完結する
経路だった:

- speech / output / remind: Companion が書き、Aidea が読む
- handoff ([ADR 0023](./0023-companion-handoff.md)): Companion → Companion
- scheduler ([ADR 0034](./0034-scheduler-snippet-dispatch.md)): 時刻/起動トリガ → Companion

「Aidea の外にいる任意のプロセス → Companion」という入口はまだ無い。

## 判断

**`.aidea/backchannels/inbox/` を新設し、外部が JSON ファイルを書き出すと Aidea が
宛先 Companion を解決してプロンプトとして送信する** (返信経路は持たない)。

配送ロジックは scheduler / handoff の dispatch を踏襲する
(宛先解決 → 未起動なら Claude セッションを起動・bind → `sendMessageWhenReady`)。

### ディレクトリと形式

| 項目 | 方針 |
|---|---|
| ディレクトリ | `.aidea/backchannels/inbox/` (Companion 別の `0..8` と同階層の非数値ディレクトリ) |
| ファイル | `inbox/*.json`。`{ "to": <index or name>, "message": "..." }` |
| 宛先 `to` | index (0..8) または Companion 名。handoff の `Target` 解決を再利用 |
| 監視 | `InboxWatcher` が `.aidea/backchannels/` を FSEvents 再帰監視し、親が `inbox` の `*.json` を処理 |
| 送信 | `message` 本文をそのまま Companion に送信し、末尾に「返信不要」の固定文言を付加 |

### 返信について

外部プロセスへ結果を返す経路は **設けない**。Companion は通常どおりプロンプトを処理し、
応答は自分の Claude タブに表示されるが、外部の送信元はそれを読み取れない。
そのため送信本文の末尾に「このメッセージへの返信は不要」の固定文言を付加し、
Companion が外部向けの返答を作ろうとして空振りするのを避ける。

## 理由

1. **既存経路の再利用**: 配送は scheduler/handoff と同型で、`sendMessageWhenReady` に集約済み。
   新規なのは「外部が書いた JSON を読む入口」だけで済む。
2. **ファイルが API**: 外部プロセスはファイルを置くだけでよく、Aidea の内部 API に依存しない
   ([backchannel.md](../specs/backchannels/backchannel.md) の設計原則を踏襲)。
3. **名前でも index でも宛先指定できる**: 外部スクリプトは Companion 名を知っていることが多いため、
   handoff の `Target` (index/name 両対応) をそのまま使う。

## 信頼境界 (重要)

**`.aidea/backchannels/inbox/` に書き込めるプロセスは、任意のプロンプトを Companion に
注入できる。** これは新しい外部入口であり、以下を前提とする:

- Aidea は **App Sandbox 無効**の個人用ローカルツールであり、`.aidea/` に書けるのは
  既に同一ユーザ権限を持つローカルプロセスに限られる (リモートからの書き込み経路は持たない)
- したがって inbox は「同一マシンの信頼できるローカルプロセス」だけが使う前提とする
- Aidea 側で送信元の認証・認可は行わない (ファイルシステム権限に委ねる)

ネットワーク越しの受付や、信頼できない入力の検疫はスコープ外とする。

## やらないこと (スコープ外)

- 外部プロセスへの**返信 (往復通信)**。inbox は一方向 (外部 → Companion) のみ。
- Aidea 起動前に置かれたファイルの取り込み。`InboxWatcher` はライブ FSEvents のみを処理し、
  起動時再スキャンは行わない (handoff と同じ。古いメッセージの誤再送を避ける)。
- 送信元の認証・レート制限・入力検疫 (信頼境界の前提により不要)。

## トレードオフ

- Aidea 稼働中でないと外部メッセージは届かない (発火点は Aidea プロセス内、[ADR 0034](./0034-scheduler-snippet-dispatch.md) と同じ前提)。
- inbox に書ける = Companion を操作できるため、書き込み権限が実質的な操作権限になる (信頼境界節のとおり許容)。
- 処理済みファイルは削除せず残す ([ADR 0024](./0024-backchannel-per-companion-archive.md))。inbox ディレクトリは時間とともに溜まるため、必要ならユーザが手で掃除する。
