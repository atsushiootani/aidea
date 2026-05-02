---
title: ポモドーロタイマー
description: ヘッダの WidgetView に常駐するポモドーロタイマー。25 分の集中フェーズと 5 分の休憩フェーズを交互に計測する
derived_from: []
syncs_with:
  - docs/specs/aspects/keybindings.md
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/window/shortcuts.md
  - docs/specs/backchannels/voicevox.md
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/widgets/README.md
last_updated: 2026-05-02
---

# ポモドーロタイマー

`AppHeaderView` の `WidgetView` に常駐するポモドーロタイマー。
25 分の **集中 (focus) フェーズ**と 5 分の **休憩 (rest) フェーズ**を交互に計測する。

GitHub Issue: [#139](https://github.com/atsushiootani/aidea/issues/139)

## UI 配置

`AppHeaderView` の `HStack` に `WidgetView` を **右端**に追加する ([../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) の現行ヘッダ階層に対する変更):

```
AppHeaderView
└─ HStack(spacing: 8)
   ├─ CompanionView                  ※既存
   ├─ speechToggleButton             ※既存 (読み上げ ON/OFF)
   ├─ Spacer                         ※既存
   └─ WidgetView                     ★新規 (右端の widget 集約コンテナ)
      └─ TimerView                   ★新規 (ポモドーロタイマーのインライン表示)
```

- **`WidgetView`** は `CompanionView` と兄弟の集約コンテナ。`Spacer` の後ろ (= 右端) に配置する
- **`TimerView`** は `WidgetView` の子。本仕様で扱う具体 widget はこれ
- 今後別の widget (TODO 等) を追加するときは、同じ `WidgetView` の子として並べる
- 実装と同時に [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) の AppHeaderView 階層図を上記に合わせて更新する

### TimerView の構成

`TimerView` は `WidgetView` の子としてヘッダに常時表示される。
popover や展開パネルでの開閉はせず、すべての操作要素を横並びでインライン表示する。

```
┌──────────────────────────────────────────────┐
│ ⏱  25:00  ▶︎  ⟲                              │
│ ▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱                 │
└──────────────────────────────────────────────┘
```

- 上段: フェーズアイコン / 残り時間 / Start・Pause / Reset を `HStack` で横並び
- 下段: 進捗ゲージを上段の幅いっぱいに横長で配置 (`VStack` で 2 段構成)

| 要素 | 役割 |
|---|---|
| フェーズアイコン | `timer` シンボル。フェーズに応じて色が変わる (focus=赤、rest=緑) |
| 残り時間表示 | `MM:SS` 形式のテキストフィールド。クリックで編集モードに入る |
| Start / Pause ボタン | タイマー開始 / 一時停止のトグル。アイコンは `▶︎` / `⏸` で切替 |
| Reset ボタン | 集中フェーズの初期状態に戻す |
| 進捗ゲージ | 上段コントロールの下に配置する横長プログレスバー。`(phaseDuration - remainingSeconds) / phaseDuration` で塗る。色はフェーズに連動 |

## 状態モデル

```swift
enum PomodoroPhase {
    case focus
    case rest
}

@Observable
final class PomodoroState {
    var phase: PomodoroPhase     // 現在のフェーズ
    var remainingSeconds: Int    // 現在のフェーズの残り秒数
    var isRunning: Bool          // 計測中なら true
    var isEditing: Bool          // 残り時間編集中フラグ
}
```

`PomodoroPhase` は `PomodoroState` のネスト型ではなく **独立した enum** として
別ファイル (`Aidea/Aidea/Widgets/Pomodoro/PomodoroPhase.swift`) に置く
([conventions/coding-style.md](../../conventions/coding-style.md) の「1 ファイル 1 型」原則)。

各フェーズの初期残り秒数:

| Phase | 秒数 | 分換算 | UI ラベル |
|---|---|---|---|
| `.focus` | 1500 | 25 分 | 集中中 |
| `.rest` | 300 | 5 分 | 休憩中 |

## 操作

### Start / Pause

- `isRunning == false` → `true` にしてカウントダウン開始 (1 秒刻み `Timer.scheduledTimer`)
- `isRunning == true` → `false` にしてカウントダウン停止 (= ポーズ)
- ボタンはトグル動作。確認ダイアログは出さない

### Reset

- 状態を `phase = .focus / remainingSeconds = 1500 / isRunning = false` に戻す
- フェーズ進行中でも問答無用でリセット (確認ダイアログなし)

### 分数の編集

- 残り時間表示はテキストフィールドとして編集可能
- 編集中 (`isEditing == true`) は `isRunning` を強制的に `false` に落とす
- 入力フォーマット:
  - `MM:SS` 形式 (例: `30:00`, `5:00`)
  - 数値のみ (整数) は分として解釈する (例: `25` → 1500 秒)
- 確定 (Enter / フォーカス外し) で `remainingSeconds` を更新する
- 不正値は赤枠で示し、確定を拒否する

### フェーズ自動遷移

`remainingSeconds` が `0` に到達したら次フェーズへ自動遷移する。

| From | To | 遷移後の残り秒数 |
|---|---|---|
| `.focus` | `.rest` | 300 |
| `.rest` | `.focus` | 1500 |

- 遷移時は `isRunning = true` を **維持**してそのまま次フェーズのカウントダウンを開始する (連続運用前提)
- 遷移と同時に **コンパニオンに読み上げ通知**を行う (下記)

### 完了通知 (コンパニオン読み上げ)

フェーズ自動遷移時に `companionIndex = 6` のコンパニオン (= 既定で concier 役) が読み上げる。

| 遷移 | 読み上げ文面 |
|---|---|
| `.focus → .rest` | 「集中タイム終わりです。5 分休憩しましょう」 |
| `.rest → .focus` | 「休憩終わりです。次の集中タイム始めましょう」 |

- 文面は実装時に微調整可。ニュアンス (concier 役の丁寧な労いトーン) は維持する
- VOICEVOX 連携の経路 ([../backchannels/voicevox.md](../backchannels/voicevox.md)):
  - 仕様上は **`SpeechQueue.enqueue(speakerId: nil, companionIndex: 6, text: ...)` を直接呼ぶ**形を想定
  - speech-{timestamp}.txt 経由 (Claude 側の発話) は使わない (Aidea 自身が発話元のため)
  - speakerId は `nil` でデフォルトスピーカーを使う (concier 役の固定話者を別途規定する場合は将来拡張)
- **読み上げが OFF (`SpeechState.isEnabled == false`) のときはスキップ**する。VOICEVOX 未起動時の扱いも voicevox.md に従う
- ユーザが手動で `Reset` した場合は読み上げない (= 自動遷移時のみ通知)

## ショートカット

| キー | 動作 |
|---|---|
| **⌘ ⌥ P** | Start / Pause トグル |
| **⌘ ⌥ ⇧ P** | Reset |

`AideaApp.body.commands` に新規 `CommandMenu("ポモドーロ")` を追加し、項目に `.keyboardShortcut` を付与する。

既存ショートカットとの衝突チェック ([../window/shortcuts.md](../window/shortcuts.md)):

- `⌘ ⌥ P` / `⌘ ⌥ ⇧ P` ともに既存定義なし → 採用可

## ゲージ表示

- `TimerView` の **下段**に横長の進捗バー (`ProgressView` ベース) を配置する
- 上段の操作 HStack と `VStack` で縦に並べ、ゲージは上段の幅いっぱいに伸ばす (固定幅にしない)
- 値: `Double(phaseDuration - remainingSeconds) / Double(phaseDuration)` (0.0 → 1.0)
- 色:
  - `.focus` フェーズ: 赤系 (Aidea のアクセント色)
  - `.rest` フェーズ: 緑系
- 残り秒数の更新と同時に再描画する

## 永続化

`PomodoroState` は **永続化しない** (アプリ再起動で常に初期状態 `phase=.focus / 1500s / isRunning=false` に戻る)。

- 一時的な作業セッション中だけ機能する想定
- `workspace.json` には書き込まない
- 動作中に Aidea が落ちても、復帰時にカウントダウンは復元しない

## 境界

- **Always**: カウントダウンは 1 秒刻みの `Timer.scheduledTimer(timeInterval: 1.0, repeats: true)` で進める
- **Always**: フェーズ遷移時は `isRunning` を維持し、即座に次フェーズの計測を始める
- **Always**: 編集モード中はカウントダウンを進めない (`isEditing == true` ならタイマー側で skip)
- **Always**: 自動フェーズ遷移時は `companionIndex = 6` で `SpeechQueue.enqueue` を呼ぶ (`SpeechState` が OFF / VOICEVOX 未起動なら voicevox.md のルールに従いスキップ)
- **Never**: `remainingSeconds` を負数にしない (0 で即フェーズ遷移)
- **Never**: TimerView を `WidgetView` の外 (Pane / Tab の中) に置かない
- **Never**: ポーズ中もカウントダウン秒数を変えない (= 残り時間表示は固定値のまま)
- **Never**: ユーザの手動 `Reset` で読み上げを発火しない (= 自動遷移時のみ通知)

## 実装メモ

- `WidgetView` は `CompanionView` と同列で `AppHeaderView` 直下に置く新規コンテナ
- `PomodoroState` は `AppHeaderView` の親 (Window/App レベル) に環境オブジェクトとして 1 つだけ持つ
- 操作 UI は popover ではなく、`WidgetView` 内に `HStack` で並べてヘッダに常時表示する
- ヘッダ全体構成は [../backchannels/voicevox.md#ui-appheaderview](../backchannels/voicevox.md#ui-appheaderview) の現行図を `WidgetView` 追加に合わせて更新する

## 関連

- [../aspects/keybindings.md](../aspects/keybindings.md) — 全ショートカット一覧 (⌘ ⌥ P / ⌘ ⌥ ⇧ P を追加)
- [../aspects/view-hierarchy.md](../aspects/view-hierarchy.md) — View 階層 (実装時に AppHeaderView 階層図に WidgetView/TimerView を追加)
- [../window/shortcuts.md](../window/shortcuts.md) — グローバルショートカット仕様 (新規 CommandMenu「ポモドーロ」を追加)
- [../backchannels/voicevox.md](../backchannels/voicevox.md) — AppHeaderView 構成と SpeechQueue 仕様
- [README.md](./README.md) — Widgets カテゴリ全体の位置付け
