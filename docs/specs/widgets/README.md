---
title: Widgets インデックス
description: ヘッダ常駐型の小さな補助機能 (タイマー / TODO 等) の widget 群を集約するディレクトリインデックス
derived_from:
  - docs/LAYOUT.md
syncs_with:
  - docs/specs/aspects/view-hierarchy.md
impacts:
  - docs/specs/widgets/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-05
---

# Widgets

ヘッダ常駐型の小さな補助機能群を集約する。
**Session** よりも軽量で、Window 全域で動作する独立した個別機能を扱う。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [pomodoro.md](./pomodoro.md) | ポモドーロタイマー (25 分作業 / 5 分休憩を交互に計測する) |
| [quick-memo.md](./quick-memo.md) | クイックメモ (Cmd+M で即開き、quickmemo/todo/ にファイル保存) |

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
   └─ WidgetView             ★新規 (右端の widget 集約コンテナ)
      ├─ TimerView           (ポモドーロ → widgets/pomodoro.md)
      ├─ QuickMemoButton     (クイックメモ → widgets/quick-memo.md)
      └─ …                   (今後追加される widget はここに並ぶ)
```

- `WidgetView` は `CompanionView` と兄弟。`Spacer` の後ろ (= 右端) に置く
- 各 widget は `WidgetView` の子としてヘッダ右端にインライン表示する。操作 UI は popover ではなくヘッダ上に常時並べる
- 個別 widget を追加 / 削除したら [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) の AppHeaderView 階層図も同時に更新する

ヘッダ全体の構成は [../backchannels/voicevox.md#ui-appheaderview](../backchannels/voicevox.md#ui-appheaderview) も参照。

## 更新ルール

- 新しい widget を追加したら、本 README の一覧表に 1 行追加し、`docs/specs/README.md` の機能群一覧にも反映する
- ショートカットを追加・変更したら [../aspects/keybindings.md](../aspects/keybindings.md) と [../window/shortcuts.md](../window/shortcuts.md) を同時に更新する
- 永続化データを持つ widget を作るときは [../aspects/persistence.md](../aspects/persistence.md) に追記する
