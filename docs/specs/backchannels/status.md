---
title: "Backchannel: ステータス (issue #281)"
description: Companion の作業状態をフキダシ表示するための単一ファイル Backchannel。Claude 自身が status.json を上書きし、書かれている文字列がそのままフキダシになる
derived_from:
  - docs/decisions/0042-status-self-report-only.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/companions/companion.md
  - docs/specs/tools/claude.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-08-10
---

# Backchannel: ステータス (issue #281)

> Companion の作業状態をフキダシ表示するための Backchannel。
> **ファイルは 1 つだけ**で、そこに書かれている文字列がそのままフキダシになる。
> 書き込むのは Claude 自身だけで、Aidea は書かない。

[backchannel.md](./backchannel.md) のメッセージ種別 `Status` を具体化した仕様。
設計判断の背景は [ADR 0042](../../decisions/0042-status-self-report-only.md) を参照。

---

## ファイル仕様

```
.aidea/backchannels/<companion-index>/status.json
```

```json
{ "status": "作業中" }
```

| 項目 | 内容 |
|---|---|
| 書き込み元 | **Claude (モデル) 自身のみ**。Aidea は書かない |
| 書き込み方式 | **上書き** (追記・タイムスタンプ付与はしない) |
| 内容 | `status` キーに表示したい文字列 1 つだけ |

他の Backchannel メッセージ (speech / output / handoff 等) と異なりタイムスタンプを持たず、履歴も
蓄積しない。これは「メッセージ」ではなく `isBusy` / `isSpeaking` と同種の**現在値**だからで、
[ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md) の
「削除せず蓄積する」対象には含めない。

### 表示条件

| 状態 | フキダシ |
|---|---|
| `status` が非空の文字列 | **その文字列をそのまま表示する** |
| `status` が空文字列 (`{"status": ""}`) | 非表示 |
| ファイルが存在しない / JSON が壊れている | 非表示 |
| Companion のセッションが未起動 | 非表示 (ファイルの内容に関わらず) |

Aidea 側は文字列の**意味を解釈しない**。固定の状態一覧を持たず、書かれたものを表示するだけ。

---

## 誰が書くか — Claude だけ

**書き込むのは Claude (モデル) 自身のみ。Aidea は一切書かない。**
`.aidea/claude/status.md` を読んだ Companion が、自分の判断で上書きする。

| タイミング | 例 |
|---|---|
| 作業に着手したとき | `少女作業中` |
| 作業のフェーズが変わったとき | `テスト実装中` / `レビュー待ち` |
| ターンを終えるとき | `待機中` |
| 返答が必要で止まるとき | `要返答` |

固定の状態一覧は持たない。文面は Companion が自由に決め、指示書 (`.aidea/claude/status.md`) が
代表例を示すだけにとどめる。

### 自己申告に委ねることの限界 ([ADR 0042](../../decisions/0042-status-self-report-only.md))

この方式には原理的な取りこぼしが 2 つある。**どちらも許容する**という判断。

1. **モデルが停止している間は書けない** — パーミッション確認等で Claude CLI が入力待ちに
   なっている間、モデルのターンは進んでいない。そのためフキダシは直前の文面のまま残る。
   指示書では「止まりそうな操作の前にあらかじめ書いておく」ことを推奨してカバーする
2. **書き忘れるとズレたまま残る** — ターン終了時の「待機中」を書き忘れると、作業が
   終わっているのに作業中の文面が残る

いずれも**フキダシは補助的な表示であり、ずれても実害が小さい**ことを踏まえた許容。
正確な実行中判定が必要な箇所は、従来どおり
[`isBusy`](../tools/claude.md#実行中判定-isbusy-issue-45) (PTY 送信起点) を使う。

---

## Companion 側の指示 (`.aidea/claude/status.md`)

Aidea が初回セットアップ時に Bundle (`Backchannels/status.md`) からコピーする指示書。
Companion はこれを読んで書き出し方を学習する。

- 書き出し先: `.aidea/backchannels/<N>/status.json` (Companion ごとに固定、上書き)
- 内容: `{"status": "<今やっていることの短い説明>"}`
- 書き出しタイミング: 作業のフェーズが変わったとき (着手時 / 実装中 → レビュー中 等)
- 文面は自由 (固定の状態一覧はない)。フキダシに収まる目安 20 文字程度を推奨

### 有効化方法

[voicevox.md の機能宣言チェーン](./voicevox.md#有効化方法-companion-instructionsmd) と同じ仕組み。
`.aidea/claude/aidea.md` の機能ファイル一覧から `status.md` を辿れるようにする。

---

## 境界

### Always

- ステータスは `status.json` **1 ファイル**で表す
- 書き込むのは **Claude 自身のみ**。Aidea はこのファイルを書かない
- 表示するのは `status` の文字列そのもの。Aidea は意味を解釈しない
- `status` が空 / ファイル不在 / JSON 破損 / セッション未起動のときはフキダシを表示しない
- `<companion-index>` は `0..8` の整数のみ有効 ([backchannel.md のハンドラ通過条件](./backchannel.md#ハンドラ通過条件) に準拠)

### Never

- ステータスを複数ファイルに分割しない (signal / label の分離はしない)
- ステータスファイルにタイムスタンプを付けたり履歴として蓄積したりしない (上書き型)
- **Aidea 側からステータスを書かない** (Claude Code hooks を含む。理由は [ADR 0042](../../decisions/0042-status-self-report-only.md))
- Companion アイコンの表情 (画像バリアント) をステータスから自動切替しない (今回のスコープ外)

---

## 関連ドキュメント

- [ADR 0042](../../decisions/0042-status-self-report-only.md) — 設計判断の背景・トレードオフ
- [backchannel.md](./backchannel.md) — Backchannel 全体の設計原則
- [../companions/companion.md#フキダシ表示-issue-281](../companions/companion.md#フキダシ表示-issue-281) — CompanionView 側の表示仕様
- [../tools/claude.md#実行中判定-isbusy-issue-45](../tools/claude.md#実行中判定-isbusy-issue-45) — 既存の `isBusy` (併存する別レイヤの信号)
- [../../decisions/0024-backchannel-per-companion-archive.md](../../decisions/0024-backchannel-per-companion-archive.md) — Companion 別保管と履歴保全の原則
