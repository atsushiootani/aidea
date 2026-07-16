---
title: "0040: 外部と Companion の往復通信 rpc backchannel を設け、MCP サーバから利用する"
description: .aidea/backchannels/rpc/ に req/res ファイルペアを置く往復チャネルを新設し、外部ツールからは tools/aidea-mcp (stdio MCP サーバ) 経由で Companion に質問して返事を受け取れるようにする
status: 提案
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-16
---

# 0040: 外部と Companion の往復通信 rpc backchannel を設け、MCP サーバから利用する

**日付**: 2026-07-16

## 背景

[ADR 0037](./0037-external-inbox-backchannel.md) で外部プロセス → Companion の一方向チャネル
(inbox) を設けたが、**返信経路は持たない**と決めた。その後、自分の PC 上の他のツール
(Claude Code / MCP クライアント全般) から Companion に「質問して返事をもらう」往復の
連携をしたいケースが出てきた。

inbox の「返信経路を持たない」決定を壊さずに往復通信を実現したい。

## 判断

**`.aidea/backchannels/rpc/` を新設し、リクエスト/レスポンスのファイルペアで往復通信を行う。**
外部ツール向けの入口として **stdio 型 MCP サーバ `tools/aidea-mcp/` をリポジトリに追加する**。

### rpc チャネル

| 項目 | 方針 |
|---|---|
| ディレクトリ | `.aidea/backchannels/rpc/` (inbox と同じく Companion 別ではない非数値ディレクトリ) |
| リクエスト | 外部が `rpc/req-<id>.json` を書く。`{ "to": <index or name>, "message": "..." }` (inbox と同スキーマ) |
| 配送 | Aidea が FSEvents で検知し、inbox と同じ dispatch 経路で宛先 Companion に `message` を送信 |
| 末尾文言 | inbox の「返信不要」文言の代わりに、**「返信を `rpc/res-<id>.txt` に書き出すこと」を指示する文言**を付加 |
| レスポンス | **宛先 Companion 自身**が `rpc/res-<id>.txt` (プレーンテキスト) を書く。Aidea は res を監視しない |
| 返信の読み取り | 外部 (MCP サーバ) が res ファイルを自分で監視して読む |

Aidea の責務は **req の配送だけ**。返信は Companion → ファイル → 外部の直行で、
Aidea は経由しない。詳細仕様は [rpc.md](../specs/backchannels/rpc.md)。

### MCP サーバ (`tools/aidea-mcp/`)

- stdio 型 MCP サーバ。MCP クライアント (Claude Code 等) が設定から都度起動する子プロセスで、常駐しない
- 起動引数 `--workspace <path>` で対象ワークスペースを指定する。**コードは 1 つで、
  ワークスペースが何個あっても設定の引数だけで切り替える**
- 提供ツール:
  - `ask_companion(to, message, timeout?)` — req を書き、res を待って返す (同期、デフォルトタイムアウト 20 秒)
  - `send_to_companion(to, message)` — 既存 inbox に書く投げっぱなし送信 (返事なし)
  - `get_reply(request_id)` — 送信済み req の res をポーリング取得 (長時間タスク用)
  - `list_companions()` — `.aidea/workspace.json` から Companion 一覧を返す
- 実装は Node + MCP SDK。リポジトリの `tools/aidea-mcp/` に置く

## 理由

1. **ADR 0037 を壊さない**: inbox は一方向のまま凍結し、往復は別ディレクトリ・別 ADR として積む。
2. **「ファイルが API」原則の維持**: MCP サーバは Aidea の内部 API に触らず、ファイルの
   読み書きだけで完結する ([backchannel.md](../specs/backchannels/backchannel.md) の設計原則)。
3. **返信は Companion 自身が書く**: speech / output と同じ「Companion がファイルを書く」型。
   Aidea が PTY 出力をスクレイピングする必要がなく、Aidea 側の変更は
   「rpc 監視の追加 + 末尾文言の差し替え」だけで済む。
4. **配送経路の再利用**: 宛先解決・自動起動・送信は inbox / handoff / scheduler の
   dispatch と同型。

## 信頼境界

[ADR 0037](./0037-external-inbox-backchannel.md) の信頼境界をそのまま踏襲する。
`.aidea/backchannels/rpc/` に書けるプロセスは任意のプロンプトを注入できるため、
**同一マシンの信頼できるローカルプロセス**だけが使う前提とする。stdio 型 MCP サーバは
ネットワークに露出しないため、この前提は自然に守られる。送信元の認証・レート制限・
入力検疫は行わない。

## やらないこと (スコープ外)

- **npm 公開・アプリバンドルへの同梱**。まずはリポジトリ内のコードとして自分用に使う。
  配布 (npm publish / Swift 化してアプリ同梱) は必要になったら別 ADR で決める。
- Aidea 未起動時の配送 (inbox と同じく発火点は Aidea プロセス内)。
- res ファイルの Aidea 側監視・UI 表示。返信は外部と Companion の間で完結する。
- ネットワーク越しの受付。

## トレードオフ

- Companion が返信を書き忘れると外部はタイムアウトするしかない。末尾文言で書き出しを
  明示指示し、MCP サーバ側のタイムアウト (デフォルト 20 秒) で拾う。
- Aidea 稼働中でないと届かない。MCP サーバはタイムアウト時に「Aidea が起動しているか」を
  疑うエラーメッセージを返す。
- req / res ファイルは削除せず残す ([ADR 0024](./0024-backchannel-per-companion-archive.md))。
  rpc ディレクトリは時間とともに溜まるため、必要ならユーザが手で掃除する。
