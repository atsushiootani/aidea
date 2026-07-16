---
title: "Backchannel: 外部 rpc (往復)"
description: 外部プロセスが .aidea/backchannels/rpc/req-<id>.json を書くと Aidea が宛先 Companion に配送し、Companion が res-<id>.txt に返信を書く往復チャネルの JSON スキーマ・配送・返信作法の仕様
derived_from:
  - docs/decisions/0040-rpc-backchannel-mcp.md
  - docs/decisions/0037-external-inbox-backchannel.md
  - docs/decisions/0023-companion-handoff.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/backchannels/inbox.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-16
---

# Backchannel: 外部 rpc (往復)

> Aidea の外にいるローカルプロセスから Companion に質問し、返信を受け取る往復チャネル

[backchannel.md](./backchannel.md) のメッセージ種別のひとつ。設計判断の背景は
[ADR 0040](../../decisions/0040-rpc-backchannel-mcp.md) を参照。
一方向で足りる用途は [inbox](./inbox.md) を使う。

---

## 概要

- 外部プロセスが `.aidea/backchannels/rpc/req-<id>.json` を書き出す
- Aidea が FSEvents で検知し、JSON の `to` から宛先 Companion を解決して `message` 本文を送信する
  (配送は inbox と同じ。末尾文言だけが異なる)
- 送信本文の末尾に **「返信を `rpc/res-<id>.txt` に書き出すこと」を指示する文言**を付加する
- 宛先 Companion が作業後、**自分で** `rpc/res-<id>.txt` (プレーンテキスト) を書き出す
- 外部プロセスは res ファイルを自分で監視して読む。**Aidea は res を監視しない**
- 配送後も req / res ファイルは削除せず残す ([ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md))

### inbox との違い

| 項目 | inbox | rpc |
|---|---|---|
| 方向 | 外部 → Companion の一方向 | 外部 ⇄ Companion の往復 |
| ディレクトリ | `inbox/*.json` | `rpc/req-<id>.json` + `rpc/res-<id>.txt` |
| 末尾文言 | 返信不要の固定文言 | res ファイルへの返信書き出し指示 |
| 返信 | なし | Companion 自身が res を書き、外部が読む |

---

## フロー

```
1. 外部プロセスが .aidea/backchannels/rpc/ に req-<id>.json を書き出す
   (ディレクトリが無ければ外部側で mkdir -p 相当で作成、原子的書き込み推奨)
2. Aidea が FSEvents で rpc/req-*.json の作成を検知
3. rpc 監視が JSON をパースし、message が空でないことを検証
4. 配送処理 (inbox と同型):
   a. to を index 解決 (index 指定 or name 逆引き。handoff の宛先解決規則を再利用)
   b. 宛先 Companion が未起動なら自動起動・bind・tab 追加
   c. 宛先 Claude セッションに message + 返信書き出し指示文言を送信
5. 宛先 Companion が作業し、返信本文を rpc/res-<id>.txt に書き出す
6. 外部プロセスが res-<id>.txt を検知して内容を読む (Aidea は関与しない)
7. req / res ファイルは削除せず残す
```

---

## リクエスト (`req-<id>.json`)

### ファイル名と `<id>`

```
req-{YYYYMMDDTHHmmss}-{ランダム英数4桁以上}.json
```

- `<id>` は `{timestamp}-{ランダム英数}` (例: `20260716T103000-a3f9`)。同秒の多重送信でも
  衝突しないよう、ランダム部を必ず付ける
- `<id>` はファイル名にのみ持たせる (JSON 内には書かない)。res のファイル名は
  この `<id>` から機械的に決まる

### JSON スキーマ

```json
{
  "to": "idea-chan",
  "message": "この設計案の懸念点を3つ挙げて"
}
```

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| `to` | number または string | はい | 宛先 Companion。[inbox](./inbox.md) の `to` と同じ解決規則 (index 直指定 or 名前の先頭マッチ) |
| `message` | string | はい | 宛先 Claude に送るプロンプト本文。空文字は無効 |

- 余分なキーは無視する
- **原子的な書き込みを推奨**: 一時ファイルに書いてから rename する (inbox と同じ理由)

---

## レスポンス (`res-<id>.txt`)

- 宛先 Companion が返信本文を**プレーンテキスト**で書き出す (JSON エスケープ不要)
- ファイル名は対応する req の `<id>` を使った `res-<id>.txt`
- 1 リクエスト 1 レスポンス。追記はせず、書き終えたファイルには以降触らない
- 書くのは宛先 Companion 自身 (speech / output と同じ「Companion がファイルを書く」型)。
  Aidea は res の生成・監視に関与しない

### 読み取り側 (外部プロセス) の注意

- Companion のファイル書き込みは原子的とは限らない。作成検知後、
  **サイズが安定するまで待ってから読む** (デバウンス) こと
- 一定時間 res が現れない場合はタイムアウトとして扱う。原因は
  「Aidea 未起動 / 宛先解決失敗 / Companion の書き忘れ」のいずれかで、外部からは区別できない

---

## 返信書き出し指示文言

送信本文の末尾に、inbox の「返信不要」文言の代わりに以下の趣旨の固定文言を付加する。

```
{message}

---
(これは外部から自動送信されたメッセージです。返信本文を
.aidea/backchannels/rpc/res-<id>.txt にプレーンテキストで書き出してください。
書き出したファイルは削除・追記しないでください)
```

- `<id>` は req のファイル名から抽出した実際の値に展開する
- 受信側 Companion に特別な事前準備は不要 (指示は配送文言に完結している)

---

## ファイル監視

rpc 監視は `.aidea/backchannels/` の FSEvents 再帰監視 (既存) に相乗りし、以下を満たすファイルのみ処理する。

- 親ディレクトリ名が `rpc`
- ファイル名が `req-*.json`

`res-*.txt` は Aidea では処理しない (外部プロセスが読む)。
既存の監視 (handoff / inbox 等) は親ディレクトリ条件が異なるため競合しない。

### 処理タイミング

- **ライブ FSEvents のみ**を処理する。**起動時の再スキャンは行わない** (inbox / handoff と同じ。
  古いリクエストの誤再送を避ける)
- パース失敗・`message` 空・宛先解決失敗はいずれも**警告ログのみ**でファイルは残す (削除・修復しない)

---

## 主要クライアント: MCP サーバ (`tools/aidea-mcp/`)

rpc の主要な書き手はリポジトリ同梱の stdio 型 MCP サーバ ([ADR 0040](../../decisions/0040-rpc-backchannel-mcp.md))。
外部ツール (Claude Code 等の MCP クライアント) はこれを設定に足すだけで Companion と往復できる。

| ツール | 動作 |
|---|---|
| `ask_companion(to, message, timeout?)` | req を書き、res を待って本文を返す。デフォルトタイムアウト 20 秒 |
| `send_to_companion(to, message)` | [inbox](./inbox.md) に書く投げっぱなし送信 (返事なし) |
| `get_reply(request_id)` | 送信済み req の res を取得 (未着なら未着と返す)。20 秒を超える作業用 |
| `list_companions()` | Companion の index と名前の一覧 |

- 起動引数 `--workspace <path>` で対象ワークスペースの `.aidea/` を特定する
- MCP サーバの詳細 (設定例・実装) は `tools/aidea-mcp/README.md` を参照

---

## 信頼境界

[inbox](./inbox.md) / [ADR 0037](../../decisions/0037-external-inbox-backchannel.md) の信頼境界を踏襲する。
`.aidea/backchannels/rpc/` に書けるプロセスは任意のプロンプトを Companion に注入できるため、
**同一マシンの信頼できるローカルプロセス**だけが使う前提とする。認証・レート制限・入力検疫は行わない。

---

## 境界

### Always

- rpc の配送対象は `.aidea/backchannels/rpc/` 直下の `req-*.json` のみ
- 宛先解決・送信は inbox / handoff / scheduler の dispatch 経路を再利用する
- 送信本文の末尾に res への返信書き出し指示文言 (実 `<id>` 入り) を付加する
- res は宛先 Companion 自身が書く
- 処理後も req / res ファイルは削除せず残す ([ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md))

### Never

- Aidea は `res-*.txt` を監視・生成・配送しない (返信は Companion と外部の直行)
- 起動時に既存の req を再スキャンしない (ライブ FSEvents のみ)
- パース不能・宛先不明のファイルを削除・修復しない (ログのみ)
- 送信元の認証・認可を行わない (ファイルシステム権限に委ねる)
- 既存 inbox の挙動 (返信不要文言) を変えない

---

## 関連ドキュメント

- [backchannel.md](./backchannel.md) — Backchannel 全体の設計原則
- [inbox.md](./inbox.md) — 一方向版の元仕様 (スキーマ・宛先解決を共有)
- [handoff.md](./handoff.md) — 宛先解決と配送の元仕様
- [../../decisions/0040-rpc-backchannel-mcp.md](../../decisions/0040-rpc-backchannel-mcp.md) — 本機能の設計判断
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/` 配下の永続化仕様
