---
title: Widgets インデックス
description: ヘッダ常駐型の小さな補助機能 (タイマー / TODO 等) の widget 群を集約するディレクトリインデックス
derived_from:
  - docs/LAYOUT.md
syncs_with:
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/backchannels/remind.md
impacts:
  - docs/specs/widgets/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-29
---

# Widgets

ヘッダ常駐型の小さな補助機能群を集約する。
**Session** よりも軽量で、Window 全域で動作する独立した個別機能を扱う。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [scheduler.md](./scheduler.md) | 定時スケジューラ (時刻+曜日で指定 Companion へ定型コマンドを自動送信。複数ジョブ。取りこぼしは未実行通知) |
| [quick-memo.md](./quick-memo.md) | クイックメモ (Cmd+M で popover を開き `.aidea/widgets/quickmemo/memo.md` に上書き保存) |
| [pomodoro.md](./pomodoro.md) | ポモドーロタイマー (25 分作業 / 5 分休憩を交互に計測する) |

## 位置付け

| 比較対象 | Widgets との違い |
|---|---|
| **Sessions** ([../sessions/](../sessions/README.md)) | Pane/Tab の中で動く作業空間ではなく、Window 全域の右上などに常駐する補助 UI |
| **Tools** ([../tools/](../tools/)) | Claude が呼び出す tool 実装ではなく、ユーザが直接操作する小機能 |
| **Aspects** ([../aspects/](../aspects/)) | 機能群横断のメタ仕様ではなく、独立した 1 個ずつの機能 |
| **Window** ([../window/](../window/)) | Window 全体の振る舞い (タブバー・ダイアログ等) ではなく、ヘッダに乗る個別機能 |

## UI 配置原則

`AppHeaderView` の `HStack` に `WidgetView` を **右端**に追加する。
現行ヘッダ階層 ([../aspects/view-hierarchy.md](../aspects/view-hierarchy.md)) との関係は以下:

```
AppHeaderView
└─ HStack(spacing: 8)
   ├─ CompanionView          ※既存 (左端: 9 体のコンパニオンアイコン)
   ├─ speechToggleButton     ※既存 (読み上げ ON/OFF)
   ├─ Spacer                 ※既存
   └─ WidgetView             (右端の widget 集約コンテナ)
      ├─ SchedulerView       (定時スケジューラ → widgets/scheduler.md)
      ├─ RemindView          (リマインド → backchannels/remind.md ※UI 配置のみ Widget)
      ├─ QuickMemoButton     (クイックメモ → widgets/quick-memo.md)
      ├─ TimerView           (ポモドーロ → widgets/pomodoro.md)
      └─ …                   (今後追加される widget はここに並ぶ)
```

> **注**: `RemindView` はデータ仕様としては Backchannel 系 ([../backchannels/remind.md](../backchannels/remind.md)) に属するが、UI 配置上はヘッダ常駐の小機能として `WidgetView` の中に並べる。Backchannel ドメイン側と UI 側を別レイヤに分け、ファイルパスは [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) を参照する。

- `WidgetView` は `CompanionView` と兄弟。`Spacer` の後ろ (= 右端) に置く
- 各 widget は `WidgetView` の子としてヘッダ右端にインライン表示する。操作 UI は popover ではなくヘッダ上に常時並べる
- 個別 widget を追加 / 削除したら [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) の AppHeaderView 階層図も同時に更新する

ヘッダ全体の構成は [../backchannels/voicevox.md#ui-appheaderview](../backchannels/voicevox.md#ui-appheaderview) も参照。

## 更新ルール

- 新しい widget を追加したら、本 README の一覧表に 1 行追加し、`docs/specs/README.md` の機能群一覧にも反映する
- ショートカットを追加・変更したら [../aspects/keybindings.md](../aspects/keybindings.md) と [../window/shortcuts.md](../window/shortcuts.md) を同時に更新する
- 永続化データを持つ widget を作るときは [../aspects/persistence.md](../aspects/persistence.md) に追記する
