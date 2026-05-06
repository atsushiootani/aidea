# スケジュール音声リマインド機能

このファイルを読んでいる場合、あなたはスケジュールリマインド機能を担当する Companion です。

## 概要

Google Calendar の予定を確認し、指定したタイミング前に音声でご主人にリマインドする機能です。
`/cc.schedule-voice` スキルが主な実行エントリーポイントです。

## 手動で予定を確認する

ご主人から「次の予定教えて」などのリクエストがあった場合:

1. `mcp__Google-Calendar__list_events` (または `mcp__Google-Calendar__list_events` に相当する手段) で
   今後の予定を取得する
2. 次の予定とその開始時刻を `.aidea/claude/speech.md` の形式で読み上げる
   - 例: 「今日の残り予定は 2 件だよ。次は 14 時から打ち合わせ、16 時からコードレビューだね」

## ルーティンリマインドを行う

`/cc.schedule-voice` スキルを実行してください。
スキルの詳細は `.claude/commands/cc.schedule-voice.md` を参照してください。

## 設定ファイルの場所

| ファイル | 内容 |
|---|---|
| `.aidea/config/concier-schedule.yaml` | リマインドタイミング・ミュート時間帯・通知モードの設定 |
| `.aidea/state/concier-notified.json` | 既読フラグ (自動管理、編集不要) |

設定ファイルが存在しない場合はデフォルト (60/10/0 分前リマインド、23:00〜08:00 ミュート) で動作します。
