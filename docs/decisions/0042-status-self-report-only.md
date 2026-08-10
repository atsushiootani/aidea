---
title: "0042: 作業状態は Claude の自己申告だけで表す (hooks を使わない)"
description: フキダシに出す作業状態は status.json 1 ファイルに Claude 自身が書く方式とし、Claude Code hooks を信号源にする案は仕組みの重さに見合わないとして採らない
status: 採用
derived_from:
  - docs/decisions/0008-no-claude-autostart.md
  - docs/decisions/0022-companion-instructions-as-files.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/status.md
  - docs/specs/backchannels/backchannel.md
  - docs/specs/companions/companion.md
  - docs/specs/tools/claude.md
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-08-10
---

# 0042: 作業状態は Claude の自己申告だけで表す (hooks を使わない)

**日付**: 2026-08-10 / **issue**: #281

## 背景

issue #281 は CompanionView に「作業中 / 要返答 / 実装中 / レビュー待ち」等の作業状態を
フキダシで常時表示したい、という要望。状態モデルの設計判断が先に必要だった:

- 状態の集合は何か
- 誰が状態を書くのか (Aidea が推測するのか、Claude が明示宣言するのか)
- 特に **「要返答」は Aidea 側から観測できるのか**
  (既存の実行中判定 `isBusy` は「PTY 出力が 0.5s 途切れたら解除」という出力静止の推測に過ぎず、
  「ターンが完了して未読出力があるだけの状態」と「Claude がパーミッション確認等でユーザ入力を
  待って止まっている状態」を区別できない。詳細は [tools/claude.md#実行中判定-isbusy-issue-45](../specs/tools/claude.md#実行中判定-isbusy-issue-45))

## 判断

**状態は `.aidea/backchannels/<companion-index>/status.json` の 1 ファイルに、
Claude (モデル) 自身だけが書き込む。Aidea は書かない。**

```json
{ "status": "少女作業中" }
```

- 書かれている文字列を**そのまま**フキダシに表示する。Aidea は意味を解釈しない
- 固定の状態集合を定義しない。文面は Companion が自由に決め、
  指示書 (`.aidea/claude/status.md`) が代表例 (`少女作業中` / `テスト実装中` / `待機中` / `要返答`) を示すだけ
- 空文字列 / ファイル不在 / JSON 破損 / セッション未起動のときは表示しない

## 検討したが採らなかった案: Claude Code hooks を信号源にする

`claude --settings <file>` で `UserPromptSubmit` / `Stop` / `Notification` 等の hooks を登録し、
Aidea が Companion ごとに生成したシェルコマンドで状態を書き込む案を検討した
(`npx mulmoterminal` の `activityHookEffects` / `hook-settings.ts` が同種の課題をこの方式で解いている)。

**この案の唯一かつ最大の利点**は、後述する「モデルが停止している間は書けない」問題を
構造的に解決できることだった。hooks は Claude CLI プロセスのライフサイクルイベントであり、
モデルの推論とは独立に発火するため、パーミッション確認で止まっている瞬間も捉えられる。

それでも採らなかった理由:

1. **仕組みが機能の価値に見合わない** — Companion ごとの hooks 設定ファイル生成、
   `--settings` の起動コマンドへの注入、シェルコマンドと Python ワンライナーの多重エスケープ、
   `notification_type` の denylist 管理が必要になる。
   フキダシは**補助的な表示**であり、ずれても実害は小さい。この規模の常設機構を
   Aidea 側に持つ費用対効果が見合わない
2. **tmux 再アタッチ経路で効かない** — 既存セッションに attach するだけの経路
   ([sessions/claude.md の経路 B](../specs/sessions/claude.md#自動起動シーケンス)) では
   `claude` コマンドを再送しないため `--settings` が渡らない。
   「使い始めるには対象 Companion の tmux セッションを畳んで起動し直す」という
   説明の要る制約が恒久的に残る
3. **書き込み元が 2 つになると設計が濁る** — hooks とモデルが同じファイルを上書きすると、
   ツール実行中のイベントでモデルの自己申告が消える問題が起きる
   (対策としてターン境界のイベントだけに絞る必要があった)。
   書き込み元を 1 つに保てば、この考慮自体が不要になる

## 理由 (自己申告方式を選ぶ理由)

1. **Aidea 側に新しい常設機構が要らない** — 既存の Backchannel (ファイル + FSEvents 監視) に
   ファイルを 1 つ足すだけで完結する。`speech` / `output` / `remind` と同じ枠組みに乗る
2. **状態集合を Aidea が決めなくてよい** — 「要返答」「レビュー待ち」といった状態の定義は
   使う人と Companion の運用に委ねられる。Aidea が enum を持つと、
   運用が変わるたびに Aidea 側の変更が必要になる
3. **既存の機能宣言チェーンに素直に乗る** — `.aidea/claude/status.md` を参照した Companion だけが
   この機能を持つ ([ADR 0022](./0022-companion-instructions-as-files.md) の段階的開示と同じ形)
4. **既存の `isBusy` を置き換えない** — `isBusy` (PTY 送信起点、issue #45) は
   アイコン表情の実行中/アイドル切替に使われ続ける。フキダシは別レイヤの補助表示として並存する

## トレードオフ (許容する取りこぼし)

1. **モデルが停止している間は書けない** — パーミッション確認等で Claude CLI が入力待ちに
   なっている間、モデルのターンは進んでいないため、その瞬間に「要返答」と書くことができない。
   フキダシは直前の文面のまま残る。
   指示書で「止まりそうな操作の前にあらかじめ書いておく」ことを推奨して部分的にカバーするが、
   **構造的な解決ではない**
2. **書き忘れるとズレたまま残る** — ターン終了時に「待機中」を書き忘れると、
   作業が終わっているのに作業中の文面が残る。プロンプト依存であるため確実性は保証されない
3. **`status.json` は上書き型で履歴を残さない** —
   [ADR 0024](./0024-backchannel-per-companion-archive.md) の「メッセージは削除せず蓄積する」
   方針の対象は Claude が明示的に書く**メッセージ**であり、`status.json` は
   `isBusy` / `isSpeaking` と同種の**現在値**と位置付けて対象外とする。
   「いつ何をしていたか」の履歴が必要な場合は蓄積型の output / speech から辿る

1 と 2 が実運用で無視できないほど頻繁に問題になるなら、
本 ADR を supersede して hooks 方式を再検討する。

## やらないこと (スコープ外)

- **表情 (アイコン画像) の切替**: 今回のスコープは「フキダシ」のみ。
  ステータス文字列を companion アイコンの表情 (issue #45 の smile/thinking バリアント) に
  反映するのは別 issue とする
- **既存 `isBusy` の判定ロジック置き換え**: `isBusy` は送信起点のタイマー判定のまま維持する
- **Aidea 側からの状態推測**: PTY 出力のパースで状態を推測しない
  ([ADR 0008](./0008-no-claude-autostart.md) の思想踏襲)
