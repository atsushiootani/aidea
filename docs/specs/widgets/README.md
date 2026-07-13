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
last_updated: 2026-07-13
---

# Widgets

ヘッダ常駐型の小さな補助機能群を集約する。
**Session** よりも軽量で、Window 全域で動作する独立した個別機能を扱う。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [snippets.md](./snippets.md) | コードスニペット (よく使うシェルコマンドをワンクリックで任意ターミナルへ送信) |
| [scheduler.md](./scheduler.md) | 定時スケジューラ (時刻+曜日で指定 Companion へ定型コマンドを自動送信。複数ジョブ。取りこぼしは未実行通知) |
| [quick-memo.md](./quick-memo.md) | クイックメモ (Cmd+M で popover を開き `.aidea/widgets/quickmemo/memo.md` に上書き保存) |
| [pomodoro.md](./pomodoro.md) | ポモドーロタイマー (25 分作業 / 5 分休憩を交互に計測する) |
| [clock.md](./clock.md) | 時計 (Widget 領域の右端に現在日時を毎秒更新で表示。表示専用) |

## 位置付け

| 比較対象 | Widgets との違い |
|---|---|
| **Sessions** ([../sessions/](../sessions/README.md)) | Pane/Tab の中で動く作業空間ではなく、Window 全域の右上などに常駐する補助 UI |
| **Tools** ([../tools/](../tools/)) | Claude が呼び出す tool 実装ではなく、ユーザが直接操作する小機能 |
| **Aspects** ([../aspects/](../aspects/)) | 機能群横断のメタ仕様ではなく、独立した 1 個ずつの機能 |
| **Window** ([../window/](../window/)) | Window 全体の振る舞い (タブバー・ダイアログ等) ではなく、ヘッダに乗る個別機能 |

## UI 配置原則 (Widget 領域)

**Widget 領域**とは、アプリヘッダの**右端**にあり、各 widget を横並びで集約するコンテナのこと。各 widget spec で「Widget 領域」と呼ぶものはこれを指す。
現行ヘッダ階層 ([../aspects/view-hierarchy.md](../aspects/view-hierarchy.md)) との関係は以下:

```
アプリヘッダ (横並び)
├─ Companion アイコン列     ※既存 (左端: 9 体のコンパニオンアイコン)
├─ 読み上げ ON/OFF ボタン   ※既存
├─ (余白)
└─ Widget 領域              (右端の widget 集約コンテナ)
   ├─ クイックメモボタン     (クイックメモ → widgets/quick-memo.md)
   ├─ スニペット widget      (コードスニペット → widgets/snippets.md)
   ├─ スケジューラ widget    (定時スケジューラ → widgets/scheduler.md)
   ├─ ポモドーロ widget      (ポモドーロ → widgets/pomodoro.md)
   ├─ リマインド widget      (リマインド → backchannels/remind.md ※UI 配置のみ Widget)
   ├─ 時計 widget            (時計 → widgets/clock.md)
   └─ …                     (今後追加される widget はここに並ぶ)
```

> **注**: リマインド widget はデータ仕様としては Backchannel 系 ([../backchannels/remind.md](../backchannels/remind.md)) に属するが、UI 配置上はヘッダ常駐の小機能として Widget 領域の中に並べる。Backchannel ドメイン側と UI 側を別レイヤに分け、実装上の対応は [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) を参照する。

- Widget 領域は Companion アイコン列と同列 (兄弟) で、余白の後ろ (= 右端) に置く
- 各 widget は Widget 領域の子としてヘッダ右端にインライン表示する。操作 UI は popover ではなくヘッダ上に常時並べる
- 個別 widget を追加 / 削除したら [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) のヘッダ階層図も同時に更新する

ヘッダ全体の構成は [../backchannels/voicevox.md#ui-アプリヘッダバー](../backchannels/voicevox.md#ui-アプリヘッダバー) も参照。

## 更新ルール

- 新しい widget を追加したら、本 README の一覧表に 1 行追加し、`docs/specs/README.md` の機能群一覧にも反映する
- ショートカットを追加・変更したら [../aspects/keybindings.md](../aspects/keybindings.md) と [../window/shortcuts.md](../window/shortcuts.md) を同時に更新する
- 永続化データを持つ widget を作るときは [../aspects/persistence.md](../aspects/persistence.md) に追記する
