---
title: "Backchannel: 外部 inbox"
description: 外部プロセス (スクリプト等) が .aidea/backchannels/inbox/*.json を書き出すと、Aidea が宛先 Companion を解決してプロンプトとして送信する外部入力チャネルの JSON スキーマ・宛先解決・監視/配送仕様。返信経路は持たない
derived_from:
  - docs/decisions/0037-external-inbox-backchannel.md
  - docs/decisions/0023-companion-handoff.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/backchannels/handoff.md
  - docs/specs/backchannels/rpc.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-16
---

# Backchannel: 外部 inbox

> Aidea の外にいる任意のローカルプロセスから Companion にメッセージ (プロンプト) を送る一方向チャネル

[backchannel.md](./backchannel.md) のメッセージ種別のひとつ。設計判断の背景は [ADR 0037](../../decisions/0037-external-inbox-backchannel.md) を参照。
返信が必要な用途は往復版の [rpc](./rpc.md) を使う (inbox 自体は一方向のまま)。

---

## 概要

- 外部プロセスが `.aidea/backchannels/inbox/*.json` を書き出す
- Aidea が FSEvents で検知し、JSON の `to` から宛先 Companion を解決する
- 宛先の Claude セッションに `message` 本文を PTY で送信する (末尾に「返信不要」の固定文言を付加)
- 宛先セッションが未起動なら自動起動し、宛先タブをアクティブ化する
- **返信経路は持たない** (外部 → Companion の一方向)。Companion の応答は自分の Claude タブに出るが、外部送信元は読み取れない
- 配送後もファイルは削除せず残す ([ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md))

### handoff との違い

| 項目 | handoff | inbox |
|---|---|---|
| 送信元 | Companion (`from` = 自分の index) | 外部プロセス (index を持たない) |
| ディレクトリ | `<from>/handoff-*.json` | `inbox/*.json` |
| PTY へ送る内容 | ファイル参照メッセージ (受信側が JSON を読む) | `message` 本文を直接送信 + 返信不要文言 |
| 返信 | 受信側 Companion がターンを回す | 返信不要 (外部は読み取れない) |

inbox は「通常のプロンプトを投げる」用途のため、本文を直接送る (handoff のようなファイル参照の間接化はしない)。

---

## フロー

```
1. 外部プロセスが .aidea/backchannels/inbox/ に JSON を書き出す
   (ディレクトリが無ければ外部側で mkdir -p 相当で作成)
2. Aidea が FSEvents で inbox/*.json の作成を検知
3. inbox 監視が JSON をパースし、message が空でないことを検証
4. 配送処理:
   a. to を index 解決 (index 指定 or name 逆引き。handoff の宛先解決規則を再利用)
   b. 宛先 Companion が未起動なら自動起動・bind・tab 追加
   c. 宛先 Claude セッションに message + 返信不要文言を送信
      (受付可能になる前なら保留され、自動起動シーケンス完了後に送られる)
5. ファイルは削除せず残す
```

---

## JSON スキーマ

```json
{
  "to": "red-chan",
  "message": "main の CI が通ったか確認して、落ちてたら原因を教えて"
}
```

| フィールド | 型 | 必須 | 内容 |
|---|---|---|---|
| `to` | number または string | はい | 宛先 Companion。number なら index (0..8) 直指定、string なら Companion 名 (trim + 大文字小文字無視の先頭マッチ)。handoff の `to` と同じ解決規則 |
| `message` | string | はい | 宛先 Claude に送るプロンプト本文。空文字は無効 |

- `from` は持たない (送信元は外部で index を持たないため)
- 余分なキーは無視する

### ファイル名の推奨: `handoff-{timestamp}.json`

inbox 監視は `inbox/*.json` であれば**ファイル名を問わず**発火するが、**推奨は `handoff-{YYYYMMDDTHHmmss}.json`** とする。

- handoff 機能 ([handoff.md](./handoff.md)) の `handoff-{timestamp}.json` と命名を揃えることで、
  外部の Claude / スクリプトが inbox に書き出すファイルの作法を handoff と共通化できる
  (「Companion にタスクを渡すファイルは `handoff-{timestamp}.json`」という 1 つの型に統一)
- テンプレートとして `inbox/handoff-YYYYMMDDTHHmmss.json` を置いておき、外部のエージェントはこれを雛形にする
- inbox の `handoff-*.json` は親ディレクトリが `inbox` (0..8 ではない) のため、handoff 監視からは
  親ディレクトリ不正として無視される (警告ログ 1 行のみ、二重処理はされない)。inbox 監視だけが処理する

> 注意: inbox の JSON スキーマは `{to, message}` で、handoff の `{from, to, task, message}` とは異なる。
> ファイル名の作法だけを揃える (inbox に `from` は不要)。

### 送信例 (シェル)

```bash
dir=.aidea/backchannels/inbox
mkdir -p "$dir"
# 一時ファイルに書いてから rename (途中書き込みを FSEvents に拾わせない)
tmp=$(mktemp)
printf '{"to":"red-chan","message":"CI の状態を確認して"}' > "$tmp"
mv "$tmp" "$dir/handoff-$(date +%Y%m%dT%H%M%S).json"
```

- **原子的な書き込みを推奨**: 直接 `>` で書くと書き込み途中に FSEvents が発火してパース失敗することがある。`mktemp` + `mv` で回避する

---

## ファイル監視

inbox 監視は `.aidea/backchannels/` を FSEvents で再帰監視し、以下を満たすファイルのみ処理する。

- 親ディレクトリ名が `inbox`
- ファイル名が `*.json`

既存の監視 (handoff 等) は親が `0..8` を要求するため inbox の JSON を弾き、競合しない。

### 処理タイミング

- **ライブ FSEvents のみ**を処理する。**起動時の再スキャンは行わない** (handoff と同じ)。
  Aidea 起動前に置かれたファイルは取り込まない (古いメッセージの誤再送を避ける)
- パース失敗・`message` 空・宛先解決失敗はいずれも**警告ログのみ**でファイルは残す (削除・修復しない)

---

## 返信不要文言

送信本文の末尾に固定文言を付加する。Companion が外部向けの返答を作ろうとして空振りするのを避けるため。

```
{message}

---
(これは外部から自動送信されたメッセージです。返信を受け取る相手はいないので、返信は不要です。指示された作業だけ行ってください)
```

---

## Aidea 側の役割分担

| 役割 | 責務 |
|---|---|
| メッセージのデコード | `inbox/*.json` を `{to, message}` としてデコードする。`to` は handoff と同じ宛先指定 (index/name) を再利用 |
| inbox 監視 | `.aidea/backchannels/` を FSEvents 再帰監視し、親が `inbox` の `*.json` をパースして配送処理に通知 (設計は handoff 監視を踏襲) |
| 配送処理 | 宛先解決 → 未起動なら Claude セッション起動・bind → message + 返信不要文言を送信 (受付可能まで保留可) |

配送はスケジューラ / handoff の配送と同型。宛先解決は handoff の解決規則を再利用する。

---

## 外部エージェント向け指示書 (`.aidea/claude/inbox.md`)

Bundle 同梱テンプレ `Backchannels/inbox.md` を初回セットアップ処理が
`.aidea/claude/inbox.md` へコピーする (既知機能ファイルの一覧に `inbox` を含む)。外部の Claude / エージェントが
inbox にファイルを書くときの作法 (書き出し先・`handoff-{timestamp}.json` 命名・JSON 形式・原子的書き込み) の
参照とする。

- **companion の `instructions.md` からは参照しない**。inbox は受信側 Companion が特別な準備をする必要がなく
  (届いた本文を通常プロンプトとして処理するだけ)、指示書は「送る側」のための参照だから
- 既存ワークスペースにも、不足している機能ファイルを後追い配布する仕組みで後から配布される

## 信頼境界

`.aidea/backchannels/inbox/` に書けるプロセスは任意のプロンプトを Companion に注入できる。
Aidea は App Sandbox 無効の個人用ローカルツールであり、inbox は**同一マシンの信頼できるローカルプロセス**だけが使う前提とする。送信元の認証・レート制限・入力検疫は行わない ([ADR 0037](../../decisions/0037-external-inbox-backchannel.md) の信頼境界節)。

---

## 境界

### Always

- inbox の対象は `.aidea/backchannels/inbox/` 直下の `*.json` のみ
- 宛先解決・送信は handoff / scheduler の dispatch 経路を再利用する
- 送信本文の末尾に返信不要文言を付加する
- 処理後もファイルは削除せず残す ([ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md))

### Never

- 外部プロセスへ返信しない (一方向チャネル)
- 起動時に既存ファイルを再スキャンしない (ライブ FSEvents のみ)
- パース不能・宛先不明のファイルを削除・修復しない (ログのみ)
- 送信元の認証・認可を行わない (ファイルシステム権限に委ねる)

---

## 関連ドキュメント

- [backchannel.md](./backchannel.md) — Backchannel 全体の設計原則
- [handoff.md](./handoff.md) — 宛先解決と配送の元仕様
- [../../decisions/0037-external-inbox-backchannel.md](../../decisions/0037-external-inbox-backchannel.md) — 本機能の設計判断と信頼境界
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/` 配下の永続化仕様
