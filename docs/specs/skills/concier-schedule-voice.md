---
title: concier-chan スケジュール音声リマインド
description: concier-chan (Companion 6) が Google Calendar の予定を取得し、設定した予告タイミングで音声リマインドを発するスキル仕様。既読フラグ・ミュート時間帯・通知モードを管理する
derived_from:
  - docs/specs/backchannels/voicevox.md
  - docs/specs/backchannels/backchannel.md
syncs_with:
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-06
---

# concier-chan スケジュール音声リマインド

> concier-chan (Companion 6) が Google Calendar の予定を取得し、設定したタイミングで音声リマインドを発する機能

## 概要

`/cc.schedule-voice` スキルを実行すると、concier-chan が Google Calendar から今後の予定を取得し、
設定した予告タイミング (デフォルト: 60 / 10 / 0 分前) を過ぎた予定に対してリマインドメッセージを
音声 (VOICEVOX) で読み上げる。

既読フラグにより同じ予定・同じタイミングの二重通知を防ぐ。ミュート時間帯は音声をサプレスし、
「通知のみ (音なし)」モードを選択できる。

---

## 呼び出し経路

| 経路 | 方法 |
|---|---|
| **手動** | concier-chan のセッション内で `/cc.schedule-voice` を実行 / 「次の予定教えて」と話す |
| **ルーティン (cron)** | `*/5 * * * * claude -p "/cc.schedule-voice" --dangerously-skip-permissions` 等でシステム cron から定期実行 |

> **注意**: ルーティン実行は [ADR 0008](../../decisions/0008-no-claude-autostart.md) の制約 (非対話シェルから claude を起動しない) を踏まえて検討すること。Aidea の外で実行する cron であれば ADR 0008 の対象外だが、環境変数 (`TERM_PROGRAM` 等) の設定が必要になる場合がある。

---

## 設定ファイル (`.aidea/config/concier-schedule.yaml`)

プロジェクトルート直下の `.aidea/config/concier-schedule.yaml` から設定を読み込む。
ファイルが存在しない場合はデフォルト値を使用する。

```yaml
# スケジュールリマインド設定
# このファイルを編集してリマインドの動作をカスタマイズできます

# リマインドする「イベント開始 N 分前」のリスト
reminder_minutes:
  - 60   # 1 時間前
  - 10   # 10 分前
  - 0    # 開始直前 (0 = 開始時刻ちょうど)

# ミュート時間帯 (この時間帯は音声をサプレスする)
# start > end の場合は日をまたぐ (例: 23:00 〜 翌 08:00)
mute_periods:
  - start: "23:00"
    end: "08:00"

# 通知モード: voice (音声あり) / silent (ログのみ、音声なし)
notification_mode: voice
```

### デフォルト値

| 設定 | デフォルト |
|---|---|
| `reminder_minutes` | `[60, 10, 0]` |
| `mute_periods` | `[{start: "23:00", end: "08:00"}]` |
| `notification_mode` | `voice` |

---

## 既読フラグ (`.aidea/state/concier-notified.json`)

同一イベント × 同一タイミングの二重通知を防ぐための状態ファイル。

```json
{
  "version": 1,
  "notified": [
    {
      "event_id": "google_calendar_event_id",
      "reminder_minutes": 60,
      "notified_at": "2026-05-06T10:00:00+09:00"
    }
  ]
}
```

| フィールド | 内容 |
|---|---|
| `event_id` | Google Calendar イベントの一意 ID |
| `reminder_minutes` | 通知したタイミング (イベント開始 N 分前) |
| `notified_at` | 通知した日時 (ISO 8601) |

古いエントリ (24 時間以上経過したイベント) は次回実行時に自動クリーンアップする。

---

## 処理フロー

```
1. .aidea/config/concier-schedule.yaml を読み込む (不在時はデフォルト値)
2. .aidea/state/concier-notified.json を読み込む (不在時は空状態)
3. 現在がミュート時間帯かどうかを判定する
4. Google Calendar から今後 24 時間以内の予定を取得する
5. 各イベントに対して reminder_minutes ごとに:
   a. 「イベント開始時刻 - reminder_minutes 分」が現在時刻を過ぎているか確認
   b. 既読フラグに (event_id, reminder_minutes) が存在しないか確認
   c. 上記どちらも満たす場合: リマインドを発火
6. リマインド発火:
   a. notification_mode == "voice" かつ非ミュート時間帯: speech ファイルを書き出す
   b. notification_mode == "silent" またはミュート時間帯: ログのみ出力
7. 発火した通知を既読フラグに追記する
8. 24 時間以上前の既読エントリをクリーンアップして保存する
```

---

## 音声出力

`voicevox.md` の仕様に従い、Companion 6 (concier-chan) として speech ファイルを書き出す。

書き出し先: `.aidea/backchannels/6/speech-{timestamp}.txt`

### メッセージテンプレート

| タイミング | テンプレート |
|---|---|
| 60 分前 | 「ご主人 あと 1 時間で [タイトル] だよ。準備はいい？」 |
| 10 分前 | 「ご主人 あと 10 分で [タイトル] が始まるよ。そろそろだね」 |
| 0 分前 | 「ご主人 今すぐ [タイトル] の時間だよ。忘れてない？」 |
| その他 N 分前 | 「ご主人 あと [N] 分で [タイトル] だよ。気をつけてね」 |
| 手動確認時 | 「今日の残り予定は [件数] 件だよ。次は [開始時刻] から [タイトル] だね」 |

文面は concier-chan らしいトーン (親しみやすく、「ご主人」呼び) で生成する。
英単語はカタカナに変換し、句読点ではスペースを入れる ([voicevox.md](../backchannels/voicevox.md) の規則に従う)。

---

## 境界

### Always

- 設定ファイルが存在しない場合はデフォルト値で動作する
- 既読フラグは `.aidea/state/concier-notified.json` に永続化する
- speech ファイルは `.aidea/backchannels/6/` に書き出す (Companion 6 固定)
- ミュート時間帯でも既読フラグは更新する (再生しないが「通知済み」として記録)
- 24 時間以上前の既読エントリは毎回クリーンアップする

### Never

- 既読フラグなしに同一 (event_id, reminder_minutes) の通知を二重送信しない
- Google Calendar 以外のカレンダーサービスを参照しない (将来拡張)
- speech ファイルを Aidea 側で削除しない ([ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md))

---

## 関連ドキュメント

- [../backchannels/voicevox.md](../backchannels/voicevox.md) — speech ファイルの書き出し仕様
- [../backchannels/backchannel.md](../backchannels/backchannel.md) — Backchannel 全体の設計原則
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/` 配下の永続化仕様
- [../../decisions/0008-no-claude-autostart.md](../../decisions/0008-no-claude-autostart.md) — claude 自動起動の制約
