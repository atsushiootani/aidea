---
title: 時計 (Clock)
description: WidgetView 右端に現在日時 (yyyy/MM/dd EEE HH:mm:ss) を毎秒更新で表示する表示専用の時計 widget
derived_from: []
syncs_with:
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/widgets/README.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-08
---

# 時計 (Clock)

`WidgetView` の**一番右**に常駐し、現在日時を表示する表示専用の widget。

## 表示

- **3 行表示**: 1 行目に日付 `yyyy/MM/dd`、2 行目に曜日 `EEE`、3 行目に時刻 `HH:mm:ss`（例: `2026/06/08` / `Tue` / `12:12:30`）。曜日は英語 3 文字 (`en_US_POSIX` 固定)、右揃え。
- **毎秒更新**する（SwiftUI の TimelineView による定期更新）。
- システムのローカルタイムゾーンで表示する。
- 等幅数字 (monospaced) で桁の揺れを抑える。

## 配置

`WidgetView` 内の並びの末尾（`TimerView` の右）に置く。

```
WidgetView
├─ SchedulerView
├─ RemindView
├─ QuickMemoButton
├─ TimerView
└─ ClockView        ← 一番右 (現在日時)
```

## 境界

### Always

- 毎秒更新し、ローカルタイムゾーンで表示する。

### Never

- 時刻の編集・アラーム・タイマー等の機能は持たない（表示専用。計測は [pomodoro.md](./pomodoro.md)、定時実行は [scheduler.md](./scheduler.md) が担う）。
