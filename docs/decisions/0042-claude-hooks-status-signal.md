---
title: "0042: Companion の作業状態は Claude Code hooks を信号源にする"
description: 要返答/実行中/アイドルの信頼できる判定を PTY 出力静止の推測ではなく Claude Code 自身の hooks (UserPromptSubmit/PreToolUse/PostToolUse/Stop/Notification) から得る。書き込み先はローカルファイル (HTTP サーバは持たない)
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
last_updated: 2026-08-07
---

# 0042: Companion の作業状態は Claude Code hooks を信号源にする

**日付**: 2026-08-07 / **issue**: #281

## 背景

issue #281 は CompanionView に「作業中 / 要返答 / 実装中 / レビュー待ち」等の作業状態を
フキダシで常時表示したい、という要望。issue コメントで既に指摘されている通り、
これは状態モデルの設計判断が先に必要:

- 状態の集合は何か
- 誰が状態を書くのか (Aidea が推測するのか、Claude が明示宣言するのか)
- 特に **「要返答」は Aidea 側から観測できるのか**
  (既存の実行中判定 `isBusy` は「PTY 出力が 0.5s 途切れたら解除」という出力静止の推測に過ぎず、
  「ターンが完了して未読出力があるだけの状態」と「Claude がパーミッション確認等でユーザ入力を
  待って止まっている状態」を区別できない。詳細は [tools/claude.md#実行中判定-isbusy-issue-45](../specs/tools/claude.md#実行中判定-isbusy-issue-45))

同種の課題を持つ他ツール (MulmoTerminal) の実装を調査したところ、
**Claude Code 自身が公開する hooks 機構**でこの区別を解決していることが分かった。

## 判断

**Companion の「実行中 / 要返答」判定は、PTY 出力の観測ではなく Claude Code の hooks
(`UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `PostToolUseFailure` / `Stop` / `Notification`)
を信号源にする。**

Claude セッション起動時 (`claude` コマンド送信時) に `--settings <file>` でこれらの hooks を
登録し、各イベント発火時に `.aidea/backchannels/<companion-index>/status-signal.json` を
上書きするシェルコマンドを command hook として仕込む。HTTP サーバは持たず、
Aidea が既に持つファイルベース Backchannel の枠組みに乗せる。

判定ロジック (MulmoTerminal の `activityHookEffects` を踏襲):

| イベント | 意味 | 書き込む state |
|---|---|---|
| `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `PostToolUseFailure` | ターン進行中 | `working` |
| `Stop` | ターン完了 (未読出力あり) | `waiting` |
| `Notification` (informational を除く) | ユーザ入力待ちで Claude 自身が停止 | `waiting` |

`Notification` の一部種別 (`agent_completed` / `auth_success` / `elicitation_complete` /
`elicitation_response` 等、サブエージェント完了など「既に起きたこと」の通知) は
「要返答」ではないため除外する (denylist 方式。将来 Claude Code が種別を増やしても
未知の種別は安全側 = 要返答扱いにする)。

これとは別に、Claude 自身が明示的に書く**自由文字列のラベル** (「テスト実装中」等) を
`status-{timestamp}.json` に持つ (issue コメントで確認済みの通り状態集合は固定 enum ではなく
自由文字列)。フキダシの文面はこのラベルを主に使い、`waiting` シグナルはラベルの有無に関わらず
優先表示する (Claude が実際に停止している瞬間はラベルを書けないため)。

役割分担の詳細は [status.md](../specs/backchannels/status.md) を参照。

## 理由

1. **モデルは「停止している瞬間」を自己申告できない**: `Notification` (パーミッション確認等) で
   Claude CLI が入力待ちになっている間、モデルのターンは進んでいない。つまり Claude 自身が
   Backchannel ファイルに「要返答です」と書くこと自体が不可能な瞬間がある。hooks は
   Claude CLI プロセスのライフサイクルイベントであり、モデルの推論とは独立に発火するため、
   この瞬間を確実に捉えられる唯一の経路になる。
2. **ターミナル出力パースに依存しない原則との整合**: [backchannel.md](../specs/backchannels/backchannel.md)
   の設計原則 3 (「ターミナル非依存」) および [ADR 0008](./0008-no-claude-autostart.md) の
   「出力の文字列パターンマッチに依存しない」思想は、PTY のテキストを読むことを禁じているのであって、
   Claude CLI 自身が発する構造化イベント (hooks) を使うこととは矛盾しない。むしろ既存の
   `isBusy` (出力静止という間接推測) より hooks (CLI 自身の直接申告) の方がこの原則に忠実。
3. **ファイルが API の原則をそのまま踏襲できる**: hooks の command は任意のシェルコマンドでよく、
   HTTP サーバを持たずファイル書き込みだけで完結する。Aidea は既に `.aidea/backchannels/` を
   FSEvents 監視しているため、新しいプロセス間通信の仕組みを増やさずに済む。
4. **既存の `isBusy` を置き換えない**: `isBusy` (PTY 送信起点、issue #45) は「アイコン表情の
   実行中/アイドル切替」に使われ続ける。今回追加する hooks シグナルは「要返答」判定という
   `isBusy` だけでは解けなかった問題にのみ使う、別レイヤの信号として並存させる
   (既存仕様への影響を最小化するため)。

## 参考実装 (調査元)

`npx mulmoterminal` (MulmoTerminal) が同種の課題を hooks で解決している。
`server/session/activity-hook.ts` の `activityHookEffects` / `INFORMATIONAL_NOTIFICATIONS`
denylist、`server/session/hook-settings.ts` の `--settings` JSON 生成が実装の元ネタ。
Aidea では HTTP サーバではなくファイル書き込みに置き換えて採用する。

## やらないこと (スコープ外)

- **表情 (アイコン画像) の切替**: issue #281 の今回のスコープは「フキダシ」のみ。
  `status-signal.json` の `waiting` を companion アイコンの表情 (issue #45 の
  smile/thinking バリアント) に反映するのは別 issue とする。
- **既存 `isBusy` の判定ロジック置き換え**: hooks シグナルへの完全移行は今回行わない。
  `isBusy` は送信起点のタイマー判定のまま維持する。
- **`Notification` の種別ごとの文面出し分け**: 「要返答」の固定文言表示のみ行い、
  パーミッション確認の具体的な内容をフキダシに転記することはしない
  (Claude が自由文字列ラベルで補足するのは可)。

## トレードオフ

- Claude セッション起動時に `--settings <file>` を注入するため、ユーザが手動で
  `--settings` を使っている場合と衝突する可能性がある (稀。Aidea が生成するファイルは
  Companion 専用パスに置き、他の設定と分離する)。
- `status-signal.json` は他の Backchannel メッセージと異なり **上書き型** (履歴を残さない)。
  [ADR 0024](./0024-backchannel-per-companion-archive.md) の「メッセージは削除せず蓄積する」
  方針の対象は Claude が明示的に書く**メッセージ**であり、`status-signal.json` は
  `isBusy`/`isSpeaking` と同種の**ランタイム信号**と位置付けて対象外とする
  (companion.md の「表情切替のために永続状態を書き換えない」境界とも整合)。
- hooks の command はシェルコマンドとして実行されるため、`.aidea/backchannels/<index>/`
  への書き込み権限を持つプロセス (= Claude CLI 自身) がその通り書き込む前提に依存する。
  信頼境界は既存の inbox/rpc ([ADR 0037](./0037-external-inbox-backchannel.md) 等) と同じく
  「同一マシン・同一ユーザ権限のローカルプロセス」を前提とする。
