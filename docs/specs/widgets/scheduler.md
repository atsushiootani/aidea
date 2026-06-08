---
title: スケジューラ (Scheduler)
description: 定時 / 起動時 / 手動のトリガーで、指定セッション (Claude Companion / 新規 Terminal) へ定型プロンプト・コマンドを送る汎用スケジューラ widget。トリガーと送信先を1つのジョブモデルに統合し、複数ジョブを設定できる
derived_from:
  - docs/decisions/0031-unified-scheduler-triggers-and-targets.md
  - docs/specs/frontchannels/frontchannel.md
syncs_with:
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/aspects/persistence.md
  - docs/specs/widgets/README.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-08
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
| `onLaunch` | なし | アプリ (リポジトリ) 起動後、セッション基盤の準備が整ったときに発火 |
| `manual` | なし | 手動 (「今すぐ実行」) のみ |

### 送信先 (どこへ送るか)

| 種別 | 追加フィールド | 送信先 |
|---|---|---|
| `claude` | `companionIndex` (0..8) | その Companion の Claude セッション (未起動なら起動して ready 後に送る) |
| `terminal` | なし | **新規 Terminal タブを起動**してコマンドを送る |

### プロンプト (何を送るか)

- `prompt`: 送信する文字列（スラッシュコマンドでも任意の指示文でも、ターミナルコマンドでもよい）。送信先に「ユーザが入力したかのように」改行付きで送る。

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
| `type` | string | `"scheduled"` / `"onLaunch"` / `"manual"` |
| `time` | string | `scheduled` のとき必須。`HH:mm`（ローカル TZ） |
| `weekdays` | int[] | `scheduled` のとき任意。省略時は毎日 `[0..6]` |

`target`:

| キー | 型 | 意味 |
|---|---|---|
| `type` | string | `"claude"` / `"terminal"` |
| `companionIndex` | int | `claude` のとき必須（`0..8`） |

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

自動管理。ユーザは通常編集しない。**`scheduled` トリガーのジョブだけ**が使う（`onLaunch` は毎起動・`manual` は都度で、実行済み管理を持たない）。

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
- **terminal**: 新規 Terminal セッション（タブ）を起動し、コマンドを送る。送信内容はジョブの `prompt` に改行（Enter 相当）を付与して PTY に送る。
- いずれも「手動実行」「定時発火」「起動時発火」で送信処理は共通。

---

## UI: SchedulerView（ヘッダ常駐 widget）

[widgets/README.md](./README.md) の `WidgetView` 内に、`RemindView`（カレンダー）の左隣に配置する。時計アイコン + テキスト + Popover の UI とする。[../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) の AppHeaderView 階層図も同期更新する。

### ヘッダ表示要素

| 要素 | 内容 |
|---|---|
| アイコン | 時計の SF Symbol（例: `clock`）。クリックで Popover を開く |
| ラベル / 状態 | 下記「状態表示」に従う |

### 状態表示（widget ラベル）

**定時 (`scheduled`) ジョブを対象**に集約する（`onLaunch` / `manual` はヘッダ集約に含めず popover 内で見る）。優先順位は **未実行（要対応） > 次回待ち > 全停止**。

| 状態 | 条件 | 見え方（目安） |
|---|---|---|
| **未実行（要対応）** | いずれかの定時ジョブが「当日未実行・時刻超過・有効」 | ⚠ 警告色で「未実行 N」 |
| **次回待ち** | 要対応が無く、有効な定時ジョブが 1 件以上 | 直近の次回発火 `HH:mm` をグレー表示 |
| **全停止** | 有効な定時ジョブが無い / ジョブ無し | グレーで「停止中」 |

### Popover: SchedulerPopoverView

登録ジョブを一覧し、**追加・編集・削除**も popover 内で完結する。各ジョブ行はトリガー種別と送信先が分かるように表示する。

| 要素 | 内容 |
|---|---|
| タイトル | 「スケジューラ」＋「＋ 追加」ボタン |
| ジョブ行 | `name` / **トリガー**（⏰ `HH:mm` 曜日 / 🚀 起動時 / ✋ 手動）/ **送信先**（Companion 名 / Terminal）/ `prompt` / 定時ジョブは本日の実行状態 |
| 今すぐ実行 | 押すと発火と同じ送信を行う。定時ジョブは当日実行済みを記録。**全トリガー種別で利用可** |
| 編集（✎） / 削除（🗑） | 該当ジョブを編集フォームに展開 / config から削除 |
| ON/OFF トグル | ジョブ単位の `enabled` 切替 |
| 空状態 | ジョブが 1 件も無いとき「ジョブなし」 |

#### 編集フォーム: SchedulerJobEditView

「＋ 追加」または行の「編集」で同じ popover 内に展開する。

| フィールド | UI | 備考 |
|---|---|---|
| 名前 (`name`) | テキスト入力 | 必須 |
| **トリガー種別** | セグメント（定時 / 起動時 / 手動） | 選択で下の時刻・曜日欄の表示が切り替わる |
| 時刻 (`time`) | 時刻ピッカー | **定時のときだけ**表示。`HH:mm` で保存 |
| 曜日 (`weekdays`) | 日〜土の 7 トグルチップ | **定時のときだけ**表示。1 つ以上選択必須 |
| **送信先種別** | セグメント（Claude / Terminal） | 選択で Companion ピッカーの表示が切り替わる |
| 送信先 (`companionIndex`) | Companion ピッカー | **Claude のときだけ**表示。CompanionStore の名前を表示 |
| プロンプト (`prompt`) | テキスト入力 | 必須 |
| 有効 (`enabled`) | トグル | |

- 新規ジョブの `id` は自動採番（`job-<8桁>`）。既存編集時は `id` を保持。
- 保存可能条件: 名前・プロンプトが非空 / 定時なら曜日が 1 つ以上 / Claude なら送信先選択済み。
- ESC で閉じる。

---

## 境界

### Always

- 発火時刻・日付はシステムのローカルタイムゾーンで解釈する。
- 送信先が未起動 (Claude 未起動 / Terminal 新規) のときは起動してから送る。Claude は ready を待つ。
- 定時ジョブの当日実行済みは `lastRun[id]` で表現し、定刻発火・手動実行のどちらでも更新する。
- 定時ジョブの取りこぼしは widget の「未実行」表示で通知し、自動実行はしない。
- 起動時ジョブはアプリ起動のたびに実行する。
- 旧スキーマのジョブは `scheduled` + `claude` として読み、保存時に新スキーマへ移行する。
- 不正・重複・必須欠落・未知の種別のジョブは警告ログでスキップし、他ジョブの動作は止めない。

### Never

- cron / launchd 等の外部スケジューラを Aidea から設定しない（発火点はアプリ内）。
- 定時ジョブの取りこぼしを勝手に遅延実行しない（手動実行に委ねる）。
- 起動時ジョブに当日実行済みのような重複抑止を入れない（毎起動で実行する）。
- ヘッドレス（`claude -p`）でジョブを起動しない（対話セッションで回す）。
- 同一の定時ジョブを同一日に二重送信しない（`lastRun[id] == 今日` の間は定刻発火しない）。
- ジョブの ON/OFF を `workspace.json` には保存しない（設定ファイル `scheduler.json` の `enabled` が単一情報源）。

---

## 関連ドキュメント

- [ADR 0031](../../decisions/0031-unified-scheduler-triggers-and-targets.md) — トリガー・送信先を1ジョブに統合した設計判断
- [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) — PTY への送信メカニズム（本機能の送信経路）
- [../sessions/terminal.md](../sessions/terminal.md) — Terminal セッション（送信先 `terminal`）
- [../backchannels/remind.md](../backchannels/remind.md) — 定時発火 + widget の姉妹仕様（発火源・発火先が異なる）
- [../backchannels/handoff.md](../backchannels/handoff.md) — 未起動セッションを起動して送る挙動の先行実装
- [./README.md](./README.md) — WidgetView 配置原則（SchedulerView の置き場）
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — AppHeaderView 階層図（SchedulerView）
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/config/` `.aidea/state/` の配置
- `quickmemo/general/system/mac-wake.md` — 定刻に Mac を起こす pmset 設定（別系統）
