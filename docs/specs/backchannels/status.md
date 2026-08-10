---
title: "Backchannel: ステータス (issue #281)"
description: Companion の作業状態をフキダシ表示するための単一ファイル Backchannel。hooks と Claude 自身が同じ status.json を上書きし、書かれている文字列がそのままフキダシになる
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
last_updated: 2026-08-10
---

# Backchannel: ステータス (issue #281)

> Companion の作業状態をフキダシ表示するための Backchannel。
> **ファイルは 1 つだけ**で、そこに書かれている文字列がそのままフキダシになる。

[backchannel.md](./backchannel.md) のメッセージ種別 `Status` を具体化した仕様。
設計判断の背景は [ADR 0042](../../decisions/0042-claude-hooks-status-signal.md) を参照。

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
| 書き込み元 | **Claude Code の hooks** と **Claude (モデル) 自身**の両方。どちらも同じファイルを上書きする |
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

## 誰がいつ書くか

同じファイルを 2 つの書き込み元が上書きするため、**後に書いた方が勝つ**。
これは競合ではなく意図した設計で、時系列で自然に上書きされる。

```
ターン開始   hooks が「作業中」を書く
    ↓
作業中       Claude が「テストを実装しています」に上書き (任意)
    ↓
ターン終了   hooks が「要返答」を書く
```

### hooks が書く (Aidea が自動で登録)

Claude セッション起動時に Aidea が hooks 設定を生成して `claude --settings` で読み込ませる。

| `hook_event_name` | 書く文字列 | 意味 |
|---|---|---|
| `UserPromptSubmit` | 作業中 (既定) | ターンが始まった |
| `Stop` | 要返答 (既定) | ターンが終わり、未読の出力がある |
| `Notification` (informational を除く) | 要返答 (既定) | ユーザ入力待ちで Claude 自身が停止した (パーミッション確認等) |

**ツール実行中のイベント (`PreToolUse` / `PostToolUse` / `PostToolUseFailure`) では書かない。**
書き込み先が 1 ファイルなので、ツール呼び出しのたびに固定文言で上書きすると
**Claude が書いた説明文がターン中に消えてしまう**ため ([ADR 0042](../../decisions/0042-claude-hooks-status-signal.md))。
hooks はターンの境界だけを担当する。

`Notification` のうち以下の `notification_type` は「既に起きたことの通知」であり要返答ではないため、
command 側で **書き込みをスキップ** する (denylist)。

- `agent_completed` (サブエージェント完了)
- `auth_success`
- `elicitation_complete`
- `elicitation_response`

`notification_type` の判定は hook の JSON payload (stdin) を読む必要があるため、この 1 イベントの
command のみ軽量なパーサを挟む。それ以外のイベントは payload を読まず固定文字列を書くだけ。
判定に失敗した場合 (フィールド欠如等) は安全側 = 要返答を書く。

#### hooks が書く文言のカスタマイズ

`.aidea/config/status-labels.json` で変更できる (`snippets.json` 等と同じ `.aidea/config/` 配置規約)。

```json
{
  "working": "少女作業中",
  "waiting": "きて〜！"
}
```

- `working` はターン開始時、`waiting` はターン終了時と入力待ち時に書かれる文字列
- ファイル不在 / デコード失敗時は既定値 (`"作業中"` / `"要返答"`) を使う
- 設定値は **hooks 設定を生成する時点で command に埋め込まれる**ため、変更を反映するには
  Aidea を再起動し、対象 Companion のセッションを起動し直す必要がある
- 保存 (write) 機能は持たない。ユーザが直接ファイルを編集する前提

### Claude (モデル) が書く

`.aidea/claude/status.md` を読んだ Companion が、作業のフェーズが変わったときに自分で上書きする。
speech と違い毎ターン書く必要はない。

---

## hooks 設定の生成 (Aidea 側)

Claude セッション起動時 (`claude` コマンドを PTY に送る直前) に、Aidea が Companion ごとの
hooks 設定 JSON を生成し、`claude --settings <file>` で読み込ませる。

```
.aidea/backchannels/<companion-index>/hooks-settings.json   ← Aidea が起動のたび上書き生成
```

- **ユーザ編集対象ではない** (Aidea が生成するたびに上書きしてよい)
- `--settings` はファイルパスを渡す (インライン JSON にしない。PTY へ打鍵する経路のため
  シェルエスケープの層を増やさない)
- 書き込みコマンドは
  `printf '%s' '{"status":"作業中"}' > '<status.json の絶対パス>'` 相当の 1 行シェルコマンド
- 外部ツール (jq 等) の事前インストールを前提にしない。`Notification` の denylist 判定には
  macOS 標準の `python3` を使う

### 起動コマンドへの注入

```
claude --settings '<escaped-path-to-hooks-settings.json>'
```

[companion.md の起動フロー](../companions/companion.md#起動フロー-claude-セッション未起動) で
`claude` を送信している箇所に `--settings` を追加する。

**tmux 再アタッチ経路 (経路 B) では hooks が付かない。** 既存セッションに attach するだけで
`claude` を再送しないため。既存セッションで有効にするには、対象 Companion の tmux セッションを
終了してから起動し直す必要がある。

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

- ステータスは `status.json` **1 ファイル**で表す。hooks と Claude は同じファイルを上書きする
- 表示するのは `status` の文字列そのもの。Aidea は意味を解釈しない
- `status` が空 / ファイル不在 / JSON 破損 / セッション未起動のときはフキダシを表示しない
- hooks が書くのは**ターンの境界** (`UserPromptSubmit` / `Stop` / `Notification`) のみ
- `--settings` に渡す hooks 設定ファイルは Companion 別ディレクトリに Aidea が起動のたび生成する
- `<companion-index>` は `0..8` の整数のみ有効 ([backchannel.md のハンドラ通過条件](./backchannel.md#ハンドラ通過条件) に準拠)
- `Notification` の denylist にない種別 (未知の種別を含む) はすべて要返答扱いにする

### Never

- ステータスを複数ファイルに分割しない (signal / label の分離はしない)
- ステータスファイルにタイムスタンプを付けたり履歴として蓄積したりしない (上書き型)
- ツール実行中のイベント (`PreToolUse` / `PostToolUse` / `PostToolUseFailure`) で hooks から
  書き込まない (Claude が書いた説明文をターン中に消してしまうため)
- hooks の command で外部ツール (jq 等) の事前インストールを前提にしない
- `--settings` にインライン JSON を渡さない (PTY 打鍵の多重エスケープを避ける)
- Companion アイコンの表情 (画像バリアント) をステータスから自動切替しない (今回のスコープ外)

---

## 関連ドキュメント

- [ADR 0042](../../decisions/0042-claude-hooks-status-signal.md) — 設計判断の背景・トレードオフ
- [backchannel.md](./backchannel.md) — Backchannel 全体の設計原則
- [../companions/companion.md#フキダシ表示-issue-281](../companions/companion.md#フキダシ表示-issue-281) — CompanionView 側の表示仕様
- [../tools/claude.md#実行中判定-isbusy-issue-45](../tools/claude.md#実行中判定-isbusy-issue-45) — 既存の `isBusy` (併存する別レイヤの信号)
- [../../decisions/0024-backchannel-per-companion-archive.md](../../decisions/0024-backchannel-per-companion-archive.md) — Companion 別保管と履歴保全の原則
