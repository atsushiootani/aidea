---
title: "Backchannel: ステータス (issue #281)"
description: Companion の作業状態をフキダシ表示するための2ファイル構成 Backchannel。要返答/実行中/アイドルは Claude Code hooks が status-signal.json に書く信頼できる信号、作業内容の自由文字列ラベルは Claude 自身が status-{timestamp}.json に書く自己申告
derived_from:
  - docs/decisions/0042-claude-hooks-status-signal.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/companions/companion.md
  - docs/specs/tools/claude.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-08-07
---

# Backchannel: ステータス (issue #281)

> Companion の作業状態をフキダシ表示するための Backchannel。
> 「要返答/実行中/アイドル」は Claude Code hooks が書く信頼できる信号、
> 「何をしているか」の自由文字列ラベルは Claude 自身が書く自己申告 — 2 系統を分離する。

[backchannel.md](./backchannel.md) のメッセージ種別 `Status` を具体化した仕様。設計判断の背景は [ADR 0042](../../decisions/0042-claude-hooks-status-signal.md) を参照。

---

## 概要

issue #281 (「companionView にステータス表示する」) が求める状態は 2 種類の性質が混ざっている。

| 種類 | 例 | 信頼性の要件 | 誰が書けるか |
|---|---|---|---|
| **信号 (signal)** | 実行中 / 要返答 / アイドル | 高 (UI の主な判断材料になる) | Claude CLI の hooks のみが正しく書ける。**Notification (パーミッション確認等) で Claude 自身が入力待ちで停止している瞬間は、モデルはターンを進めておらずファイルを書けない** |
| **ラベル (label)** | 「テストを実装しています」「PR 作成待ち」 | 低 (あれば嬉しい説明文。無くても signal だけで表示は成立する) | Claude (モデル) が自由文字列で明示宣言 |

この非対称性から、**書き込み元の異なる 2 ファイルに分離する** (1 ファイルに両方持たせると、
hooks の command (シェルの単純な上書き) と Claude の Write ツール (JSON 全体書き換え) が
競合し、どちらかの更新が失われるおそれがあるため)。

---

## ファイル仕様

### signal ファイル (hooks が書く、上書き型)

```
.aidea/backchannels/<companion-index>/status-signal.json
```

| 項目 | 内容 |
|---|---|
| 書き込み元 | Claude Code の hooks (Aidea がセッション起動時に登録するコマンド) |
| 書き込み方式 | **上書き** (追記・タイムスタンプ付与はしない) |
| 内容 | `{"state": "working" \| "waiting" \| "idle"}` |

他の Backchannel メッセージ (speech / output / handoff 等) と異なりタイムスタンプを持たない。
これは「メッセージ」ではなく `isBusy` / `isSpeaking` と同種の**ランタイム信号**だからで、
[ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md) の
「削除せず蓄積する」対象には含めない (ADR 0042 のトレードオフ節を参照)。

#### イベント → state のマッピング

Claude Code hooks の `hook_event_name` ごとに、対応する command hook が固定の `state` を書き込む
(hooks の command 自体は payload を解析しない。イベントの種類ごとに別々の command 文字列を
登録することで判定を hooks 登録側に持たせ、シェル側の JSON パースを不要にする)。

| `hook_event_name` | 書き込む `state` | 意味 |
|---|---|---|
| `UserPromptSubmit` | `working` | ユーザ (または Aidea) がプロンプトを送った |
| `PreToolUse` / `PostToolUse` / `PostToolUseFailure` | `working` | ツール実行中 (ターン継続中の再アサート) |
| `Stop` | `waiting` | ターン完了、未読出力あり |
| `Notification` (informational を除く) | `waiting` | ユーザ入力待ちで Claude 自身が停止 (パーミッション確認等) |

`Notification` のうち以下の `notification_type` は「既に起きたことの通知」であり要返答ではないため、
command 側で **書き込みをスキップ** する (denylist、[ADR 0042](../../decisions/0042-claude-hooks-status-signal.md) 参照)。

- `agent_completed` (サブエージェント完了)
- `auth_success`
- `elicitation_complete`
- `elicitation_response`

`notification_type` の判定は hook の JSON payload (stdin) を読む必要があるため、この 1 イベントの
command のみ軽量なパーサ (後述) を挟む。それ以外のイベントは payload を読まず固定文字列を書くだけ。

`idle` を明示的に書き込む hook イベントは無い (Claude CLI が完全に終了した = PTY が閉じたときに
Aidea 側で `idle` とみなす。詳細は「Aidea 側の解釈」節)。

### label ファイル (Claude が書く、蓄積型)

```
.aidea/backchannels/<companion-index>/status-{timestamp}.json
```

既存の speech / output と同じ命名規則 (`{timestamp}` は `YYYYMMDDTHHmmss`)。**1 ファイル 1 宣言**、
削除しない (ADR 0024 と同じ扱い)。

| 項目 | 内容 |
|---|---|
| 書き込み元 | Claude (モデル自身、Write ツール) |
| 書き込み方式 | 新規作成 (追記しない) |
| 内容 | `{"label": "<自由文字列>"}` |

`label` は固定 enum ではなく自由文字列 (issue #281 のご主人判断)。UI 側は文字列をそのまま
フキダシに表示するだけで、意味解釈は行わない。

---

## hooks 設定の生成 (Aidea 側)

Claude セッション起動時 (`claude` コマンドを PTY に送る直前) に、Aidea が Companion ごとの
hooks 設定 JSON ファイルを生成し、`claude --settings <file>` で読み込ませる。

```
.aidea/backchannels/<companion-index>/hooks-settings.json   ← Aidea が起動のたび上書き生成
```

- **ユーザ編集対象ではない** (instructions.md 等と違い、Aidea が生成するたびに上書きしてよい)
- `--settings` は Claude Code CLI の標準フラグで、ファイルパスまたはインライン JSON を受け付ける
  (`claude --help` で確認済み)。PTY に文字列として打鍵する経路のため、インライン JSON ではなく
  **ファイルパスを渡す** (シェルエスケープの層を増やさないため)

### 生成される hooks 設定の形

```json
{
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "<working を書く command>" }] }],
    "PreToolUse":       [{ "matcher": "", "hooks": [{ "type": "command", "command": "<working を書く command>" }] }],
    "PostToolUse":      [{ "matcher": "", "hooks": [{ "type": "command", "command": "<working を書く command>" }] }],
    "PostToolUseFailure":[{ "matcher": "", "hooks": [{ "type": "command", "command": "<working を書く command>" }] }],
    "Stop":             [{ "hooks": [{ "type": "command", "command": "<waiting を書く command>" }] }],
    "Notification":     [{ "hooks": [{ "type": "command", "command": "<denylist 判定 + waiting を書く command>" }] }]
  }
}
```

- `working` / `waiting` を書く command はどちらも
  `printf '{"state":"%s"}' <state> > '<status-signal.json の絶対パス>'` 相当の 1 行シェルコマンド
  (パスは Companion ごとに固定なので埋め込み時点で決定できる)
- `Notification` の command のみ、標準入力の JSON から `notification_type` を取り出して
  denylist と照合してから書き込む。jq 等の外部ツールに依存せず、macOS 標準の `python3` で
  1 行実装する (`python3 -c 'import json,sys; ...'`)。判定に失敗した場合 (フィールド欠如等) は
  安全側 = `waiting` を書く (ADR 0042 の「未知の種別は要返答扱い」方針)
- 生成したファイルパスは `--settings` に渡す 1 箇所のみに使われ、他の Companion 設定とは
  混ざらない (Companion 別ディレクトリに分離しているため)

### 起動コマンドへの注入

```
claude --settings '<escaped-path-to-hooks-settings.json>'
```

[companion.md の起動フロー](../companions/companion.md#起動フロー-claude-セッション未起動) で
`claude\n` を送信している箇所に `--settings` を追加する。パスのシェルエスケープは
既存の `command` 生成 (`ClaudeSessionState.terminalView` 内、projectRoot のエスケープと同じ手法)
に揃える。

tmux 再アタッチ経路 (経路 B、既存セッションに attach するだけで `claude` を再送しない) では
hooks は前回起動時に登録済みのため、何もしない。

---

## Aidea 側の解釈

CompanionView が読む「現在の状態」は、signal ファイルと label ファイルを合成して求める。

**label がある場合は常に label を優先表示する** (signal 由来の固定文言より Claude 自身の
説明文の方が情報量が多いため)。signal は「label が無いときのフォールバック文言」と
「idle 時にフキダシごと隠す」の 2 点だけに使う。

```
1. status-signal.json の state を読む (未起動 / ファイル不在なら idle 扱い)
2. state が idle なら、label の有無に関わらずフキダシを表示しない
3. state が working / waiting のとき:
   - 最新の status-{timestamp}.json に label があれば、それを表示する (state を問わず label 優先)
   - label が無い場合のみ signal 由来のフォールバックを使う
     (文言は .aidea/config/status-labels.json でカスタマイズ可能、次節参照)
```

具体的な View 実装は [companion.md のフキダシ節](../companions/companion.md#フキダシ表示-issue-281) を参照。

### フォールバック文言のカスタマイズ

signal 由来のフォールバック文言 (label が無いときに `working` / `waiting` それぞれで表示する文字列) は
固定文言ではなく、ユーザが `.aidea/config/status-labels.json` で自由にカスタマイズできる
(`snippets.json` 等と同じ `.aidea/config/` 配置規約)。

```json
{
  "working": "少女作業中",
  "waiting": "きて〜！"
}
```

- ファイル不在 / デコード失敗時は既定値 (`"working"` / `"waiting"`) にフォールバックする
- `idle` はカスタマイズ対象外 (常にフキダシ自体を非表示)
- アプリ起動時に 1 回読み込む方式 (ライブリロードはしない)。編集後は Aidea の再起動が必要
- 保存 (write) 機能は持たない。ユーザが直接ファイルを編集する前提 (`StatusLabelsStore.swift`)

---

## Companion 側の指示 (`.aidea/claude/status.md`)

Aidea が初回セットアップ時に Bundle (`Backchannels/status.md`) からコピーする指示書。
Companion はこれを読んで label の書き出し方を学習する (signal は hooks が自動で書くため
Companion 側は関与しない)。

### 指示書の骨子

- 書き出し先パスとファイル名形式: `.aidea/backchannels/<N>/status-{timestamp}.json`
- 内容: `{"label": "<今やっていることの短い説明>"}`
- 書き出しタイミング: 作業のフェーズが変わったとき (着手時 / 実装中 → レビュー中 等)。
  speech と違い毎ターン書く必要はない
- 文面は自由 (固定の状態一覧はない)。短く (フキダシに収まる目安 20 文字程度) を推奨

### 有効化方法

[voicevox.md の機能宣言チェーン](./voicevox.md#有効化方法-companion-instructionsmd) と同じ仕組み。
`.aidea/claude/aidea.md` の機能ファイル一覧に `status.md` への参照を追加し、使いたい Companion は
instructions.md (または aidea.md 経由) から辿れるようにする。

---

## 境界

### Always

- signal (`status-signal.json`) は hooks のみが書く。Claude (モデル) が Write ツールで直接
  書き換えない (書いても Aidea 側の解釈は signal を優先するため実害は薄いが、役割分離のため
  status.md の指示書では触れない)
- label (`status-{timestamp}.json`) は Claude が明示的に書いたときのみ更新される。Aidea が
  自動生成しない
- `--settings` に渡す hooks 設定ファイルは Companion 別ディレクトリに Aidea が起動のたび生成する
- `<companion-index>` は `0..8` の整数のみ有効 ([backchannel.md のハンドラ通過条件](./backchannel.md#ハンドラ通過条件) に準拠)
- `Notification` の denylist にない種別 (未知の種別を含む) はすべて `waiting` 扱いにする

### Never

- signal ファイルにタイムスタンプを付けたり履歴として蓄積したりしない (上書き型)
- signal と label を同一ファイルに持たせない (書き込み元の競合を避けるため)
- hooks の command で外部ツール (jq 等) の事前インストールを前提にしない (macOS 標準ツールのみ使う)
- `--settings` にインライン JSON を渡さない (PTY 打鍵の多重エスケープを避けるため、ファイルパスのみ)
- Companion アイコンの表情 (画像バリアント) を signal から自動切替しない (今回のスコープ外、ADR 0042)

---

## 関連ドキュメント

- [ADR 0042](../../decisions/0042-claude-hooks-status-signal.md) — 設計判断の背景・トレードオフ
- [backchannel.md](./backchannel.md) — Backchannel 全体の設計原則
- [../companions/companion.md#フキダシ表示-issue-281](../companions/companion.md#フキダシ表示-issue-281) — CompanionView 側の表示仕様
- [../tools/claude.md#実行中判定-isbusy-issue-45](../tools/claude.md#実行中判定-isbusy-issue-45) — 既存の `isBusy` (併存する別レイヤの信号)
- [../../decisions/0024-backchannel-per-companion-archive.md](../../decisions/0024-backchannel-per-companion-archive.md) — Companion 別保管と履歴保全の原則
