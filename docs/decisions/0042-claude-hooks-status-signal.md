---
title: "0042: Companion の作業状態は Claude Code hooks を信号源にする"
description: 作業状態の信頼できる判定を PTY 出力静止の推測ではなく Claude Code 自身の hooks から得る。書き込み先は単一のローカルファイル status.json で、hooks とモデルが同じファイルを上書きする
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

**Companion の作業状態は Claude Code の hooks を信号源にし、`.aidea/backchannels/<companion-index>/status.json`
という「1 ファイル 1 文字列」に書き込む。**

```json
{ "status": "作業中" }
```

Claude セッション起動時 (`claude` コマンド送信時) に `--settings <file>` で hooks を登録し、
各イベント発火時にこのファイルを上書きするシェルコマンドを command hook として仕込む。
HTTP サーバは持たず、Aidea が既に持つファイルベース Backchannel の枠組みに乗せる。

**同じファイルを Claude (モデル) 自身も上書きする。** 「テストを実装しています」のような
自由文字列を書けば、それがそのままフキダシになる。書き込み元を分けず、**後に書いた方が勝つ**。

| イベント | 意味 | 書く文字列 (既定) |
|---|---|---|
| `UserPromptSubmit` | ターン開始 | 作業中 |
| `Stop` | ターン完了 (未読出力あり) | 要返答 |
| `Notification` (informational を除く) | ユーザ入力待ちで Claude 自身が停止 | 要返答 |

`Notification` の一部種別 (`agent_completed` / `auth_success` / `elicitation_complete` /
`elicitation_response` 等、サブエージェント完了など「既に起きたこと」の通知) は
「要返答」ではないため除外する (denylist 方式。将来 Claude Code が種別を増やしても
未知の種別は安全側 = 要返答扱いにする)。

### ツール実行中のイベントでは書かない

`PreToolUse` / `PostToolUse` / `PostToolUseFailure` は hooks の対象に**含めない**。

書き込み先が 1 ファイルであるため、ツール呼び出しのたびに固定文言で上書きすると
**Claude が書いた説明文がターンの途中で消える**。ツール呼び出しは数秒間隔で起きるので、
自己申告の文面は実質的に一度も表示されないことになり、
issue #281 の目的 (「何をしているか」を見えるようにする) が達成できない。

hooks は**ターンの境界**だけを担当し、ターン中の内容は Claude 自身の申告に任せる。

```
ターン開始   hooks が「作業中」を書く
    ↓
作業中       Claude が「テストを実装しています」に上書き (任意)
    ↓
ターン終了   hooks が「要返答」を書く
```

ツール実行中の再アサートを失う代償として、hooks が 1 つも発火しなかった場合の復旧力は下がるが、
ターン境界の 2 イベントで十分に追従できる。

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
4. **1 ファイルにすることで書き込み元の分離が不要になる**: 当初は「hooks が書く信号」と
   「モデルが書くラベル」を別ファイルに分ける案を採ったが、
   利用者から見れば**フキダシに出る文字列は 1 つ**であり、2 ファイルを合成して 1 つの文字列を
   決めるロジックは仕様・実装・デバッグのすべてを複雑にしていた。
   上書き競合は「後に書いた方が勝つ」で時系列的に自然に解決し、
   ツール実行中の hooks を落とすことで実害も消える。
5. **既存の `isBusy` を置き換えない**: `isBusy` (PTY 送信起点、issue #45) は「アイコン表情の
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
  `status.json` の内容を companion アイコンの表情 (issue #45 の
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
- `status.json` は他の Backchannel メッセージと異なり **上書き型** (履歴を残さない)。
  [ADR 0024](./0024-backchannel-per-companion-archive.md) の「メッセージは削除せず蓄積する」
  方針の対象は Claude が明示的に書く**メッセージ**であり、`status.json` は
  `isBusy`/`isSpeaking` と同種の**現在値**と位置付けて対象外とする
  (companion.md の「表情切替のために永続状態を書き換えない」境界とも整合)。
  「いつ何をしていたか」の履歴が必要になった場合は、蓄積型の output/speech から辿る。
- hooks とモデルが同じファイルを上書きするため、**書き込みの取りこぼしを検出できない**
  (誰がいつ書いたかを残さないため)。表示が実態とずれた場合の原因追跡は難しくなるが、
  フキダシは補助的な表示であり、ずれても実害が小さいことを踏まえて許容する。
- hooks の command はシェルコマンドとして実行されるため、`.aidea/backchannels/<index>/`
  への書き込み権限を持つプロセス (= Claude CLI 自身) がその通り書き込む前提に依存する。
  信頼境界は既存の inbox/rpc ([ADR 0037](./0037-external-inbox-backchannel.md) 等) と同じく
  「同一マシン・同一ユーザ権限のローカルプロセス」を前提とする。
