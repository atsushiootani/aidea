---
title: 時計 (Clock)
description: Widget 領域の右端に現在日時 (yyyy/MM/dd EEE HH:mm:ss) を毎秒更新で表示する表示専用の時計 widget
derived_from: []
syncs_with:
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/widgets/README.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# 時計 (Clock)

[Widget 領域](./README.md#ui-配置原則-widget-領域) の**一番右**に常駐し、現在日時を表示する表示専用の widget。

## 表示

- **3 行表示**: 1 行目に日付 `yyyy/MM/dd`、2 行目に曜日 `EEE`、3 行目に時刻 `HH:mm:ss`（例: `2026/06/08` / `Tue` / `12:12:30`）。曜日は**英語 3 文字で固定**（システムの言語設定に依存しない）、右揃え。
- **毎秒更新**する。
- システムのローカルタイムゾーンで表示する。
- 等幅数字 (monospaced) で桁の揺れを抑える。

## 配置

Widget 領域内の並びの末尾（ポモドーロ widget の右）に置く。

```
Widget 領域
├─ スケジューラ widget
├─ リマインド widget
├─ クイックメモボタン
├─ ポモドーロ widget
└─ 時計 widget        ← 一番右 (現在日時)
```

## 境界

### Always

- 毎秒更新し、ローカルタイムゾーンで表示する。

### Never

- 時刻の編集・アラーム・タイマー等の機能は持たない（表示専用。計測は [pomodoro.md](./pomodoro.md)、定時実行は [scheduler.md](./scheduler.md) が担う）。
