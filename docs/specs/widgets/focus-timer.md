---
title: 没入防止タイマー
description: ヘッダの WidgetView に常駐する没入防止タイマー。設定した時間が経過するとコンシェルちゃん (companion index 6) へ読み上げとフロントチャネルで相談を促すメッセージを送る
derived_from: []
syncs_with:
  - docs/specs/aspects/keybindings.md
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/window/shortcuts.md
  - docs/specs/companions/companion.md
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/backchannels/voicevox.md
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/widgets/README.md
last_updated: 2026-05-06
---

# 没入防止タイマー

`AppHeaderView` の `WidgetView` に常駐する没入防止タイマー。
タスクに没入して時間を忘れることを防ぐため、設定した時間が経過すると
コンパニオン (concier 役 / index 6) に読み上げとフロントチャネルで相談を促すメッセージを送る。

GitHub Issue: [#138](https://github.com/atsushiootani/aidea/issues/138)

## 目的

- 長時間のタスク調査・掘り下げ作業で「気づいたら一日経っていた」を防ぐ
- 時間が来たら自動でコンシェルちゃんに呼びかけてもらい、メンバーへの相談を促す

## UI 配置

```
AppHeaderView
└─ HStack(spacing: 8)
   ├─ CompanionView                  ※既存
   ├─ speechToggleButton             ※既存
   ├─ Spacer                         ※既存
   └─ WidgetView                     ※既存
      ├─ TimerView                   ※既存 (ポモドーロ)
      └─ FocusTimerView              ★新規 (没入防止タイマー)
```

### FocusTimerView の構成

通常時:

```
┌──────────────────────────────────────────────┐
│ ⏳  30:00  ▶︎  ⟲                              │
│ ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱                 │
└──────────────────────────────────────────────┘
```

時間切れ時 (アイコン点滅・ゲージ満タン・Start ボタン無効):

```
┌──────────────────────────────────────────────┐
│ 🔔  00:00      ⟲                             │
│ ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰ (オレンジ)        │
└──────────────────────────────────────────────┘
```

| 要素 | 役割 |
|---|---|
| タイマーアイコン | 通常: 砂時計 (青)、時間切れ: ベル (オレンジ、点滅) |
| 残り時間表示 | `MM:SS` 形式のテキストフィールド。クリックで編集モードに入る |
| Start / Pause ボタン | タイマー開始 / 一時停止のトグル。時間切れ後は無効 |
| Reset ボタン | 初期状態 (30 分) に戻す |
| 進捗ゲージ | 経過率 (オレンジ) を横長で表示 |

## 状態

- 計測時間: **30 分 (1800 秒)** をデフォルトとする。ユーザが編集した値を反映
- 残り時間: カウントダウン中の現在値
- 実行状態: 計測中 / 停止中 / 時間切れ の 3 状態
- 編集中フラグ: 時間フィールド編集中は計測を停止する
- 永続化しない (アプリ再起動で常に初期状態に戻る)

## 操作

### Start / Pause

- 停止中 → 計測開始 (1 秒刻みカウントダウン)
- 計測中 → 一時停止
- 時間切れ状態では開始できない (Reset してから開始する)

### Reset

- 計測時間・残り時間をデフォルト (30 分) に戻し、時間切れフラグを解除する

### 時間の編集

- ポモドーロタイマーと同じ書式: `MM:SS` または整数 (分) を受け付ける
- 編集確定で計測時間 (基準値) と残り時間の両方を更新する (進捗ゲージも初期化)

## 時間切れ時の動作

残り時間が 0 に到達したとき、以下を順に実行する:

1. 計測を停止し、時間切れ状態に遷移する
2. **読み上げ通知**: SpeechQueue 経由でコンパニオン index 6 (concier 役) に読み上げさせる

   > 「没入防止タイマーが切れました。そろそろメンバーに相談しましょう」

   `SpeechState.isEnabled == false` / VOICEVOX 未起動の場合はスキップ (voicevox.md のルールに従う)

3. **フロントチャネル送信**: companion index 6 に PTY 経由で以下のメッセージを送信する

   > 「没入防止タイマーが切れました。今のタスクについてメンバーに相談することをお勧めします。詰まっていること・進捗・試したことを整理してみましょう。」

   - companion が未起動の場合は起動してから送信する
   - 送信後に companion のタブをアクティブにする

## ショートカット

| キー | 動作 |
|---|---|
| **⌘ ⌥ F** | 没入防止タイマー 開始 / 一時停止 |
| **⌘ ⌥ ⇧ F** | 没入防止タイマー リセット |

`AideaApp.body.commands` に `CommandMenu("没入防止タイマー")` を追加する。
既存ショートカットとの衝突なし。

## 境界

- **Always**: カウントダウンは 1 秒刻みで進める
- **Always**: 時間切れ時は companion index 6 で SpeechQueue への読み上げ通知を行う (`SpeechState` が OFF / VOICEVOX 未起動なら voicevox.md のルールに従いスキップ)
- **Always**: 時間切れ時は companion index 6 にフロントチャネルでメッセージを送信する
- **Always**: 時間の編集確定で計測基準値と残り時間を同時に更新する
- **Never**: 残り時間を負数にしない
- **Never**: 時間切れ状態のままカウントダウンを再開しない (Reset してから開始する)
- **Never**: ユーザの手動 Reset で読み上げ / フロントチャネル送信を発火しない
- **Never**: `FocusTimerView` を `WidgetView` の外に置かない

## 関連

- [../aspects/keybindings.md](../aspects/keybindings.md) — 全ショートカット一覧 (⌘⌥F / ⌘⌥⇧F を追加)
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — View 階層 (FocusTimerView を WidgetView の子として追加)
- [../window/shortcuts.md](../window/shortcuts.md) — グローバルショートカット仕様 (CommandMenu 追加)
- [../companions/companion.md](../companions/companion.md) — companion index 6 (concier 役) の定義
- [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) — PTY 送信メカニズム
- [../backchannels/voicevox.md](../backchannels/voicevox.md) — SpeechQueue 仕様
- [README.md](./README.md) — Widgets カテゴリ全体
