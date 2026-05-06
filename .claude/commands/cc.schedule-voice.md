---
description: concier-chan がGoogle Calendar の予定を取得し、設定したタイミング (60/10/0 分前) で音声リマインドを発するスキル。既読フラグ・ミュート時間帯を管理する
---

# cc.schedule-voice

concier-chan (Companion 6) が Google Calendar の予定を確認し、設定したタイミングで音声リマインドを発するスキル。

## 使い方

- **手動確認**: concier-chan のセッション内で `/cc.schedule-voice` を実行
- **即時確認**: 「次の予定教えて」と話す
- **ルーティン**: cron (`*/5 * * * *` 等) から定期実行する

## やること

### 1. 設定を読み込む

`<projectRoot>/.aidea/config/concier-schedule.yaml` を読み込む。

ファイルが存在しない場合はデフォルト値を使用する:
- `reminder_minutes: [60, 10, 0]`
- `mute_periods: [{start: "23:00", end: "08:00"}]`
- `notification_mode: voice`

### 2. 既読フラグを読み込む

`<projectRoot>/.aidea/state/concier-notified.json` を読み込む。

ファイルが存在しない場合は空の状態 (`{"version": 1, "notified": []}`) として扱う。

### 3. ミュート時間帯を判定する

現在時刻が `mute_periods` のいずれかに該当するか確認する。
- `start > end` の場合は日をまたぐ (例: `23:00` 〜 翌 `08:00`)
- ミュート中でもフローを続ける (既読フラグは更新する。speech ファイルは書き出さない)

### 4. Google Calendar から予定を取得する

`mcp__Google-Calendar__list_events` を使い、今後 24 時間以内の予定を取得する。

- 取得できない場合 (権限エラー等) はエラーをユーザに報告して終了する

### 5. リマインドが必要な予定を判定する

各イベント × 各 `reminder_minutes` の組み合わせについて:

```
trigger_time = event.start - reminder_minutes 分
現在時刻 >= trigger_time                           → 時刻条件を満たす
(event_id, reminder_minutes) が既読フラグにない    → 未通知条件を満たす
両方を満たす場合 → リマインドを発火する
```

### 6. リマインドを発火する

条件を満たすイベントについて、以下を実行する。

#### 音声出力 (notification_mode == "voice" かつ非ミュート)

自分の Companion index を `.aidea/claude/companions/<N>/instructions.md` のパスから特定し、
`.aidea/backchannels/<N>/speech-{timestamp}.txt` に書き出す。

**メッセージテンプレート**:

| reminder_minutes | メッセージ |
|---|---|
| 60 | 「ご主人 あと 1 時間で [タイトル] だよ。準備はいい？」 |
| 10 | 「ご主人 あと 10 分で [タイトル] が始まるよ。そろそろだね」 |
| 0 | 「ご主人 今すぐ [タイトル] の時間だよ。忘れてない？」 |
| その他 N | 「ご主人 あと [N] 分で [タイトル] だよ。気をつけてね」 |

speech ファイルの形式は `.aidea/claude/speech.md` の仕様に従う。
(1 行目: スピーカーID省略可、2 行目以降: テキスト本文。英単語はカタカナ変換、句読点はスペース区切り)

#### ミュート中または silent モード

speech ファイルを書き出さずにログのみ出力する。
既読フラグへの追記は通常通り行う。

### 7. 既読フラグを更新する

発火した通知を既読フラグに追記する:

```json
{
  "event_id": "<Google Calendar イベント ID>",
  "reminder_minutes": <N>,
  "notified_at": "<ISO 8601 現在時刻>"
}
```

24 時間以上前のイベントに対するエントリは削除してから保存する。

ファイルが存在しない場合は新規作成する。
ディレクトリが存在しない場合は `mkdir -p` 相当で作成してから保存する。

### 8. 実行結果を報告する

以下の形式でユーザ (またはルーティンログ) に報告する:

```
🔔 スケジュールリマインド確認完了

## 通知したイベント
- 14:00「打ち合わせ」→ 10 分前リマインド済み

## 今後の予定 (24 時間以内)
- 14:00「打ち合わせ」
- 16:00「コードレビュー」

## スキップ (理由)
- 「打ち合わせ」60 分前: 既読 (09:00 に通知済み)
```

通知したイベントがない場合: 「今後 24 時間以内にリマインドすべき予定はなかったよ」と報告する。

## 注意

- このスキルは **1 回実行で完結** する。再実行は呼び出し側 (ルーティン / ユーザ) の責務
- speech ファイルは削除しない ([ADR 0024](../../../docs/decisions/0024-backchannel-per-companion-archive.md))
- Google Calendar の認証エラーは復旧せずユーザに報告して終了する
- `<projectRoot>` は `.aidea/claude/companions/<N>/instructions.md` のパスから自動推定する
  (例: `/Users/foo/myproject/.aidea/claude/companions/6/instructions.md` → projectRoot = `/Users/foo/myproject`)
