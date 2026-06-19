---
title: スケジューラ (Scheduler)
description: 定時 / 起動時 / 手動のトリガーで、指定セッション (Claude Companion / 新規 Terminal) へ定型プロンプト・コマンドを送る汎用スケジューラ widget。トリガーと送信先を1つのジョブモデルに統合し、複数ジョブを設定できる
derived_from:
  - docs/decisions/0031-unified-scheduler-triggers-and-targets.md
  - docs/decisions/0034-scheduler-snippet-dispatch.md
  - docs/specs/frontchannels/frontchannel.md
syncs_with:
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/aspects/persistence.md
  - docs/specs/widgets/README.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-19
---

# スケジューラ (Scheduler)

> 任意の「トリガー + 送信先 + プロンプト」を**ジョブ**として複数登録し、定時 / 起動時 / 手動で発火させる汎用スケジューラ

ヘッダ常駐 widget。各ジョブは **いつ実行するか (トリガー)** と **どこへ送るか (送信先)** と **何を送るか (プロンプト)** を持つ。トリガーと送信先を1つのジョブモデルに統合した経緯は [ADR 0031](../../decisions/0031-unified-scheduler-triggers-and-targets.md) を参照。

朝メモ生成 (`/cc.morning` を concier-chan へ定時送信) はこのスケジューラの 1 ジョブとして実現する代表例だが、用途は朝ルーティンに限らない。

発火の送信経路は [frontchannel.md](../frontchannels/frontchannel.md)（PTY への送信）。定時発火 + widget という構成は [remind.md](../backchannels/remind.md) と似るが、**発火源・発火先・繰り返し・取りこぼし時の扱いが異なる**。

| 観点 | Remind | スケジューラ (本仕様) |
|---|---|---|
| トリガ源 | Companion が書いたファイル（ファイル名=絶対時刻） | **アプリ内** (定時 / アプリ起動時 / 手動) |
| 繰り返し | 1 回だけ（絶対時刻） | トリガー種別による (定時=毎日 / 起動時=毎起動 / 手動=都度) |
| 発火先 | SpeechQueue（音声読み上げ） | **指定セッション** (Claude Companion / 新規 Terminal) へプロンプト送信 |
| 取りこぼし時 | 過去なら読み上げずスキップ | **定時ジョブのみ** 自動実行せず「未実行」を widget で通知 |

---

## 概要

ユーザの定型作業を、`claude -p` のヘッドレス実行ではなく **Aidea 上の対話セッション**で回すための仕組み。アプリが常駐している前提で、各ジョブを定時 / 起動時 / 手動で発火させ、指定セッションへ送信する。

ヘッドレス実行を避けることで対話セッション扱いとなり、サブスク枠で動作する（プログラム実行向けの別課金区分を回避できる）。Mac 自体の起動維持は別系統（`pmset` による定刻 wake、`quickmemo/general/system/mac-wake.md`）が担う。

### 設計原則

1. **発火点はアプリ内** — cron / launchd 等の外部スケジューラに依存しない。Aidea が起動中であることを前提とする（[remind.md](../backchannels/remind.md) の原則 4 と同じ）。
2. **IDE にロックインしない** — 送信する中身は単なるコマンド文字列。Aidea が無くても素のターミナルで同じコマンドが叩ける（コマンド本体はユーザースコープに置かれる前提）。
3. **取りこぼしは自動補完しない** — 定時ジョブが定刻を逃した場合、勝手に遅延実行せず、ユーザに「未実行」を提示して**手動実行に委ねる**。
4. **設定はファイルで宣言** — ジョブは設定ファイルで持ち、コードを触らず追加・変更できる。
5. **汎用** — 特定用途（朝ルーティン）に固定しない。
6. **トリガーと送信先を統合** — 「実行トリガーが違うだけの同じジョブ」を二重実装しない。トリガー (定時/起動時/手動) と送信先 (Claude/Terminal) は1ジョブモデルの種別フィールドで表す ([ADR 0031](../../decisions/0031-unified-scheduler-triggers-and-targets.md))。

---

## ジョブモデル

各ジョブは次の3要素を持つ。

### トリガー (いつ実行するか)

種別ごとに必要なフィールドだけを持つ「タグ付きユニオン」とする。

| 種別 | 追加フィールド | 発火タイミング |
|---|---|---|
| `scheduled` | `time` (`HH:mm`) / `weekdays` (0=日〜6=土) | 設定時刻・曜日に毎日発火 |
| `cron` | `expr` (cron 式 5 フィールド) | cron 式に一致する分ごとに繰り返し発火 (壁時計アライン) |
| `onLaunch` | なし | アプリ (リポジトリ) 起動後、セッション基盤の準備が整ったときに発火 |
| `manual` | なし | 手動 (「今すぐ実行」) のみ |

`cron` は「5 分ごと」「6 時間ごと」のような**周期発火**のための種別。詳細な式の構文は [後述](#cron-式の構文) を参照。`scheduled` との違いは「1 日 1 回 (定時) か / 周期で繰り返すか」で、cron は当日実行済み管理 (`lastRun`) も取りこぼし通知も持たない ([ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md))。

### 送信先 (どこへ送るか)

| 種別 | 追加フィールド | 送信先 |
|---|---|---|
| `claude` | `companionIndex` (0..8) | その Companion の Claude セッション (未起動なら起動して ready 後に送る) |
| `terminal` | `sessionTitle` (任意, タブ名) | `sessionTitle` 省略時は**新規 Terminal タブ**。指定時はその**タブ名**のターミナルへ送る (同名タブが無ければ**その名前で新規タブを作ってフォールバック**) |

`terminal` のタブ名指定は [ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md) を参照。Claude が Companion を選べるのと同様に、Terminal も「新規タブ / タブ名指定」を選べる。タブ名はタブの表示タイトル (ユーザーがリネームしたカスタム名、無ければ `Terminal N`)。

### プロンプト (何を送るか)

- `prompt`: 送信する文字列（スラッシュコマンドでも任意の指示文でも、ターミナルコマンドでもよい）。送信先に「ユーザが入力したかのように」改行付きで送る。

---

## cron 式の構文

`cron` トリガーの `expr` は **標準 5 フィールド**（空白区切り）とする。連続する空白は 1 つの区切りとして扱う。

```
┌─ 分 (0-59)
│ ┌─ 時 (0-23)
│ │ ┌─ 日 (1-31)
│ │ │ ┌─ 月 (1-12)
│ │ │ │ ┌─ 曜日 (0-6, 0=日)
│ │ │ │ │
* * * * *
```

各フィールドで使える記法（最小サブセット）:

| 記法 | 意味 | 例 |
|---|---|---|
| `*` | 全値 | `* * * * *` = 毎分 |
| `*/n` | n 刻み（0 起点） | `*/5 * * * *` = 0,5,10… 分 |
| `a` | 単一値 | `0 9 * * *` = 毎日 9:00 |
| `a-b` | 範囲 | `0 9-18 * * *` = 9〜18 時の毎時 0 分 |
| `a-b/n` | 範囲内 n 刻み | `0-30/10 * * * *` = 0,10,20,30 分 |
| `a,b,c` | 値リスト（上記を `,` で連結可） | `0,30 * * * *` / `*/15,45 * * * *` |

- **曜日**: `0`=日〜`6`=土。互換のため `7`=日も受理して `0` に正規化する。
- **日 (dom) と曜日 (dow) の扱い**: 両方が `*` 以外（制限あり）のときは **OR**（どちらか一致で発火）。片方が `*` のときはもう一方のみが効く（Vixie cron 互換）。
- 値が各フィールドの範囲外、フィールド数が 5 でない、未知のトークンが含まれる場合は**パース失敗**としジョブをスキップする。
- **非対応**（[ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md)）: 月名・曜日名（`JAN` / `MON` 等）、`@daily` 等のマクロ、秒フィールド（6 フィールド）、`L` / `W` / `#` などの拡張記法。

代表例:

| やりたいこと | expr |
|---|---|
| 5 分ごと | `*/5 * * * *` |
| 6 時間ごと（0/6/12/18 時） | `0 */6 * * *` |
| 1 時間ごと（毎時 0 分） | `0 * * * *` |
| 平日 9-18 時の 10 分ごと | `*/10 9-18 * * 1-5` |

### 発火セマンティクス

- **壁時計アライン**: cron 式に一致する「分」が来たら発火する。起動時刻や前回発火からの相対ではない。
- **粒度は 1 分**。秒は常に 0 として扱う。
- アプリ常駐中、一致する分ごとに繰り返し発火する。スリープ等で逃した分は**自動補完しない**（取りこぼしの概念を持たない）。スリープ復帰時は現在時刻基準で次回発火を張り直す。
- 当日実行済み管理 (`lastRun`) を持たない（周期発火のため二重送信抑止の対象外）。

---

## 設定ファイル

ユーザが編集する宣言的設定。**JSON 形式**とする（外部依存を SwiftTerm のみに保つ方針のため YAML パーサを導入しない）。

### パス

```
.aidea/config/scheduler.json
```

### 形

`jobs` 配列を持つ。各ジョブ:

| キー | 型 | 既定値 | 意味 |
|---|---|---|---|
| `id` | string | （必須） | ジョブ識別子（一意）。状態ファイルのキー・重複送信判定に使う |
| `name` | string | `id` と同じ | 表示名 |
| `enabled` | bool | `true` | 有効 / 無効 |
| `trigger` | object | （必須） | 下記「トリガー」 |
| `target` | object | （必須） | 下記「送信先」 |
| `prompt` | string | （必須） | 送信する文字列 |

`trigger`:

| キー | 型 | 意味 |
|---|---|---|
| `type` | string | `"scheduled"` / `"cron"` / `"onLaunch"` / `"manual"` |
| `time` | string | `scheduled` のとき必須。`HH:mm`（ローカル TZ） |
| `weekdays` | int[] | `scheduled` のとき任意。省略時は毎日 `[0..6]` |
| `expr` | string | `cron` のとき必須。cron 式 5 フィールド（[cron 式の構文](#cron-式の構文)） |

`target`:

| キー | 型 | 意味 |
|---|---|---|
| `type` | string | `"claude"` / `"terminal"` |
| `companionIndex` | int | `claude` のとき必須（`0..8`） |
| `sessionTitle` | string | `terminal` のとき任意。送信先タブ名。省略時は新規タブ |

### 例

```json
{
  "jobs": [
    {
      "id": "morning",
      "name": "朝ルーティン",
      "enabled": true,
      "trigger": { "type": "scheduled", "time": "08:00", "weekdays": [0, 1, 2, 3, 4, 5, 6] },
      "target": { "type": "claude", "companionIndex": 6 },
      "prompt": "/cc.morning"
    },
    {
      "id": "dev-server",
      "name": "開発サーバ起動",
      "enabled": true,
      "trigger": { "type": "onLaunch" },
      "target": { "type": "terminal" },
      "prompt": "npm run dev"
    },
    {
      "id": "trend-poll",
      "name": "トレンド巡回 (6時間ごと)",
      "enabled": true,
      "trigger": { "type": "cron", "expr": "0 */6 * * *" },
      "target": { "type": "claude", "companionIndex": 6 },
      "prompt": "/cc.trend.claude"
    },
    {
      "id": "log-tail",
      "name": "ログ監視端末へ送信",
      "enabled": true,
      "trigger": { "type": "onLaunch" },
      "target": { "type": "terminal", "sessionTitle": "ログ監視" },
      "prompt": "tail -f var/log/app.log"
    }
  ]
}
```

- 設定ファイルが存在しない場合は**ジョブ無し**として扱う。
- 不正値（時刻パース不可・index が範囲外・`id` 重複・必須欠落・未知の種別）は警告ログを出し、当該ジョブをスキップする（他ジョブには影響させない）。

### マイグレーション (旧スキーマ後方互換)

旧スキーマはジョブ直下に `time` / `weekdays` / `companionIndex` を持っていた。

```json
{ "id": "morning", "time": "08:00", "weekdays": [0,1,2,3,4,5,6], "companionIndex": 6, "prompt": "/cc.morning" }
```

`trigger` / `target` が無く旧フィールドを持つジョブは、読み込み時に **`trigger: scheduled(time, weekdays)` + `target: claude(companionIndex)`** として解釈する。これにより既存の `scheduler.json` は無変更のまま動く。保存時は新スキーマで書き出す。

---

## 状態ファイル

自動管理。ユーザは通常編集しない。**`scheduled` トリガーのジョブだけ**が使う（`cron` は周期発火・`onLaunch` は毎起動・`manual` は都度で、いずれも実行済み管理を持たない）。

### パス

```
.aidea/state/scheduler.json
```

### 形

| キー | 型 | 意味 |
|---|---|---|
| `lastRun` | object | ジョブ `id` → 最後に送信した日付 `YYYY-MM-DD`（ローカル TZ）のマップ |

```json
{ "lastRun": { "morning": "2026-06-08" } }
```

- `scheduled` ジョブの「本日実行済み」判定は `lastRun[id] == 今日の日付`。
- 手動実行・定刻発火のどちらでも、送信したらそのジョブ `id` を当日日付で更新する。

---

## トリガー別の挙動

### scheduled (定時)

- アプリ常駐中、設定時刻に**毎日**発火する。日をまたいでも次回分が登録され続ける。
- 発火時に `enabled` と `weekdays`（当日が含まれるか）と「当日未実行」(`lastRun`) を確認し、満たさなければ送信しない。
- **取りこぼし**: アプリ起動時、「当日まだ未実行」かつ「設定時刻を過ぎている」かつ「有効」なら、自動実行はせず widget で「未実行」状態にして通知する。ユーザが「今すぐ実行」を押すと送信し当日実行済みを記録する。
- **スリープ復帰時の張り直し**: アプリ内タイマーはシステムスリープ中に進まないため、復帰を検知したら取りこぼし判定を再計算し、各ジョブの次回発火を現在時刻基準で再登録する。

### cron (周期)

- アプリ常駐中、cron 式に一致する分が来るたびに発火する（壁時計アライン）。日をまたいでも次回分が登録され続ける。
- 発火時に確認するのは `enabled` のみ。曜日・時間帯の絞り込みは cron 式自体に内包されるため、別途の weekdays チェックや当日未実行チェックは行わない。
- **取りこぼしの概念は無い**。スリープ等で逃した分は自動補完せず、復帰後の次回一致分から再開する。`scheduled` のような「未実行」通知も出さない。
- **スリープ復帰時の張り直し**: `scheduled` と同様、復帰を検知したら現在時刻基準で次回発火を再登録する。
- 当日実行済み (`lastRun`) の記録・参照は行わない（周期発火のため二重送信抑止の対象外）。

### onLaunch (起動時)

- アプリ (リポジトリ) 起動後、セッション基盤の準備が整ったときに発火する。
- **毎起動で実行する**（当日実行済みのような重複管理は行わない）。同じ日に何度起動しても起動のたびに実行する。
- 取りこぼしの概念は無い（起動した時点が実行タイミングのため）。

### manual (手動のみ)

- 自動では発火しない。widget の「今すぐ実行」でのみ送信する。
- 重複管理は無い。

---

## 送信先 (セッション送信)

- **claude**: ジョブの `companionIndex` の Companion セッションへ送る。セッションが未起動なら起動し、Claude の初期化完了 (ready) を待ってから送信する（[handoff.md](../backchannels/handoff.md) の挙動と同じ）。その Companion として扱う（表情・ビジー表示も同じ）。
- **terminal**: 送信内容はジョブの `prompt` に改行（Enter 相当）を付与して PTY に送る。送信先タブは `sessionTitle` で決まる（[ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md)）。
  - `sessionTitle` 省略 (`nil`/空): **新規 Terminal タブ**を起動して送る（従来挙動）。
  - `sessionTitle` 指定: 表示タイトルが一致する**生存中のターミナルタブ**があればそれを activate して送る（複数一致は最初の 1 つ）。**無ければその名前で新規タブを作って送る**（フォールバック。サイレントにスキップしない）。これにより次回以降は同名タブに当たり、発火のたびにタブが増えない。
- いずれも「手動実行」「定時発火」「cron 発火」「起動時発火」で送信処理は共通。

---

## UI: SchedulerView（ヘッダ常駐 widget）

[widgets/README.md](./README.md) の `WidgetView` 内に、`RemindView`（カレンダー）の左隣に配置する。時計アイコン + テキスト + Popover の UI とする。[../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) の AppHeaderView 階層図も同期更新する。

### ヘッダ表示要素

| 要素 | 内容 |
|---|---|
| アイコン | 時計の SF Symbol（例: `clock`）。クリックで Popover を開く |
| ラベル / 状態 | 下記「状態表示」に従う |

### 状態表示（widget ラベル）

優先順位は **未実行（要対応） > 次回待ち > 全停止**。**未実行（要対応）は定時 (`scheduled`) ジョブのみ**を対象とする。**次回待ちは時刻発火する `scheduled` と `cron` の両方**の直近発火を集約する（`onLaunch` / `manual` はヘッダ集約に含めず popover 内で見る）。

| 状態 | 条件 | 見え方（目安） |
|---|---|---|
| **未実行（要対応）** | いずれかの**定時**ジョブが「当日未実行・時刻超過・有効」 | ⚠ 警告色で「未実行 N」 |
| **次回待ち** | 要対応が無く、有効な `scheduled` / `cron` ジョブの次回発火が 1 件以上 | 直近の次回発火 `HH:mm` をグレー表示 |
| **全停止** | 有効な時刻発火ジョブが無い / ジョブ無し | グレーで「停止中」 |

### Popover: SchedulerPopoverView

登録ジョブを一覧し、**追加・編集・削除**も popover 内で完結する。各ジョブ行はトリガー種別と送信先が分かるように表示する。

| 要素 | 内容 |
|---|---|
| タイトル | 「スケジューラ」＋「＋ 追加」ボタン |
| ジョブ行 | `name` / **トリガー**（⏰ `HH:mm` 曜日 / ⏱ cron 式 / 🚀 起動時 / ✋ 手動）/ **送信先**（Companion 名 / タブ名 or `Terminal (新規)`）/ `prompt` / 定時ジョブは本日の実行状態 |
| 今すぐ実行 | 押すと発火と同じ送信を行う。定時ジョブは当日実行済みを記録。**全トリガー種別で利用可** |
| 編集（✎） / 削除（🗑） | 該当ジョブを編集フォームに展開 / **確認ダイアログ**で確認してから config から削除 |
| ON/OFF トグル | ジョブ単位の `enabled` 切替 |
| 空状態 | ジョブが 1 件も無いとき「ジョブなし」 |

#### 編集フォーム: SchedulerJobEditView

「＋ 追加」または行の「編集」で同じ popover 内に展開する。

| フィールド | UI | 備考 |
|---|---|---|
| 名前 (`name`) | テキスト入力 | 必須 |
| **トリガー種別** | セグメント（定時 / cron / 起動時 / 手動） | 選択で下の時刻・曜日 / cron 欄の表示が切り替わる |
| 時刻 (`time`) | 時刻ピッカー | **定時のときだけ**表示。`HH:mm` で保存 |
| 曜日 (`weekdays`) | 日〜土の 7 トグルチップ | **定時のときだけ**表示。1 つ以上選択必須 |
| cron 式 (`expr`) | テキスト入力 + プリセット | **cron のときだけ**表示。プリセット（5分 / 6時間 等）で式を流し込める。入力に応じて次回発火 `HH:mm` かパースエラーをライブ表示 |
| **送信先種別** | セグメント（Claude / Terminal） | 選択で送信先ピッカーの表示が切り替わる |
| 送信先 (`companionIndex`) | Companion ピッカー | **Claude のときだけ**表示。CompanionStore の名前を表示 |
| 送信先 (`sessionTitle`) | タブ名入力 (選択 + 自由入力) | **Terminal のときだけ**表示。「新規タブ」+ 現在のターミナルタブ名をクイック選択でき、任意のタブ名をテキスト入力もできる (未起動のタブ名も指定可) |
| プロンプト (`prompt`) | テキスト入力 | 必須 |
| 有効 (`enabled`) | トグル | |

- 新規ジョブの `id` は自動採番（`job-<8桁>`）。既存編集時は `id` を保持。
- 保存可能条件: 名前・プロンプトが非空 / 定時なら曜日が 1 つ以上 / cron なら式がパース可能 / Claude なら送信先選択済み。
- ESC で閉じる。

---

## 境界

### Always

- 発火時刻・日付はシステムのローカルタイムゾーンで解釈する。
- 送信先が未起動 (Claude 未起動 / Terminal 新規) のときは起動してから送る。Claude は ready を待つ。
- `terminal` 送信で `sessionTitle` 指定タブが発火時に存在しないときは、その名前で新規タブを起動して送る (フォールバック)。
- ジョブ削除は確認ダイアログで確認してから実行する。
- 定時ジョブの当日実行済みは `lastRun[id]` で表現し、定刻発火・手動実行のどちらでも更新する。
- 定時ジョブの取りこぼしは widget の「未実行」表示で通知し、自動実行はしない。
- cron ジョブは壁時計アラインで一致する分ごとに発火し、`scheduled` / `cron` 両方の次回発火をヘッダの「次回待ち」に集約する。
- 起動時ジョブはアプリ起動のたびに実行する。
- cron 式の日 (dom) と曜日 (dow) が両方制限されているときは OR で判定する（片方が `*` ならもう一方のみ）。
- 旧スキーマのジョブは `scheduled` + `claude` として読み、保存時に新スキーマへ移行する。
- 不正・重複・必須欠落・未知の種別のジョブは警告ログでスキップし、他ジョブの動作は止めない。

### Never

- cron / launchd 等の外部スケジューラを Aidea から設定しない（発火点はアプリ内。`cron` トリガーは Aidea 内のタイマーで発火し、OS の crontab は使わない）。
- cron パーサに外部ライブラリを導入しない（最小サブセットを自前実装。月名・曜日名・`@daily` 等のマクロ・秒フィールド・`L`/`W`/`#` 拡張は非対応）。
- cron ジョブに取りこぼし通知・当日実行済み管理を入れない（周期発火のため。逃した分は自動補完しない）。
- 定時ジョブの取りこぼしを勝手に遅延実行しない（手動実行に委ねる）。
- 起動時ジョブに当日実行済みのような重複抑止を入れない（毎起動で実行する）。
- ヘッドレス（`claude -p`）でジョブを起動しない（対話セッションで回す）。
- 同一の定時ジョブを同一日に二重送信しない（`lastRun[id] == 今日` の間は定刻発火しない）。
- ジョブの ON/OFF を `workspace.json` には保存しない（設定ファイル `scheduler.json` の `enabled` が単一情報源）。

---

## 関連ドキュメント

- [ADR 0031](../../decisions/0031-unified-scheduler-triggers-and-targets.md) — トリガー・送信先を1ジョブに統合した設計判断
- [ADR 0034](../../decisions/0034-scheduler-snippet-dispatch.md) — cron 式トリガー・Terminal タブ名指定・スニペット送信先・変換移動をまとめた設計判断
- [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) — PTY への送信メカニズム（本機能の送信経路）
- [../sessions/terminal.md](../sessions/terminal.md) — Terminal セッション（送信先 `terminal`）
- [../backchannels/remind.md](../backchannels/remind.md) — 定時発火 + widget の姉妹仕様（発火源・発火先が異なる）
- [../backchannels/handoff.md](../backchannels/handoff.md) — 未起動セッションを起動して送る挙動の先行実装
- [./README.md](./README.md) — WidgetView 配置原則（SchedulerView の置き場）
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — AppHeaderView 階層図（SchedulerView）
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/config/` `.aidea/state/` の配置
- `quickmemo/general/system/mac-wake.md` — 定刻に Mac を起こす pmset 設定（別系統）
