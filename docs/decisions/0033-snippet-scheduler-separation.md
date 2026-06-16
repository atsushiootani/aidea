---
title: コードスニペットとスケジューラを別モデル・別 UI で持つ
status: 採用
date: 2026-06-16
---

# ADR 0033: コードスニペットとスケジューラを別モデル・別 UI で持つ

## 状態

採用

## 背景

「ボタン一発でターミナルに送って実行できる、よく使うシェルコマンドの置き場」が欲しい。
スケジューラ (ADR 0031) は `trigger: .manual` + `target: .terminal` の組み合わせで技術的には同じことができる。
しかしユーザーの認知モデルでは「スケジューラ = いつ動かすか」「スニペット = 何をすぐ実行するか」は別物であり、同じ UI に混在させると両方の見通しが悪くなる。

## 決定

コードスニペットを **独立したモデル・独立した widget** として実装する。

| 観点 | コードスニペット (本 ADR) | スケジューラ (ADR 0031) |
|---|---|---|
| モデル | `SnippetConfig` (id / name / command / enabled) | `SchedulerConfig.Job` (trigger / target / prompt) |
| トリガー | なし (手動のみ) | scheduled / onLaunch / manual |
| 送信先 | Terminal のみ (実行先を選択可) | Claude / Terminal (ジョブに固定) |
| 実行履歴 | なし | scheduled のみ lastRun 管理 |
| config | `.aidea/config/snippets.json` | `.aidea/config/scheduler.json` |
| widget ショートカット | ⌥⌘B | ⌥⌘S |

### 実行先の選択

スニペットはボタンを押した瞬間に「どのターミナルへ送るか」を選べる (スケジューラは常に新規タブ)。

| 選択肢 | 挙動 |
|---|---|
| アクティブターミナル | アクティブセッションが Terminal ならそこへ、なければ開いている最初の Terminal、それも無ければ新規タブ |
| Terminal N | 特定のターミナルセッションを指定 |
| 新規ターミナルタブ | 常に新規タブを開く |

### 双方向変換 (ブリッジ)

UI レベルでの相互移行を提供し、「スニペットだったが定期実行したくなった」ケースに対応する。

- **スニペット → スケジューラ**: `SnippetRowView` の「→ スケジューラ」ボタン → `trigger: .manual, target: .terminal` のジョブとして登録。ユーザがその後スケジューラで trigger を変更できる。
- **スケジューラ → スニペット**: `SchedulerRowView` の「→ スニペット」ボタン → `prompt` を `command` としてスニペット登録。

### 実行パスの共有

技術レベルでは送信先 Terminal の扱いにのみ差異がある。
スケジューラの `dispatchTerminalJob` は「常に新規タブ」で固定。
スニペットの `dispatchSnippetCommand` は上記 3 種の実行先をサポートする。
両者は `AideaApp` の static メソッドとして実装し、UI 層から切り離す。

## 代替案

### 却下: スケジューラの manual+terminal ジョブとして実装

技術的には可能だが、スケジューラの UI にスニペット群が混在し、定時ジョブの見通しが悪くなる。
「今すぐ実行したいだけ」のコマンドに trigger / weekdays フォームが出るのも混乱を招く。

### 却下: trigger に `.snippet` を追加

スケジューラモデルに「スケジュールしない」種別を追加するのは概念的に矛盾。

## 結果

- `SnippetConfig` / `SnippetStore` / `SnippetState` を追加 (scheduler 系と並行構成)
- `SnippetView` / `SnippetPopoverView` / `SnippetRowView` / `SnippetEditView` を追加
- `WidgetView` に `SnippetView` (⌥⌘B) を追加
- `SchedulerRowView` に「→ スニペット」ブリッジを追加
- `SnippetRowView` に「→ スケジューラ」ブリッジを追加
