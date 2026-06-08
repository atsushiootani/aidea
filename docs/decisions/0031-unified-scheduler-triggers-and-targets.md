---
title: "0031: 定時・起動時・手動トリガーを1ジョブに統合しスケジューラを汎用化する"
description: 定時スケジューラを拡張し、実行トリガー (定時/起動時/手動) と送信先 (Claude/Terminal) を1つのジョブモデルに統合する。起動時実行を別機能にせず、プロンプト・送信先・UI・dispatch を共有する決定
status: 提案
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-06-08
---

# 0031: 定時・起動時・手動トリガーを1ジョブに統合しスケジューラを汎用化する

**日付**: 2026-06-08

## 背景

[定時スケジューラ](../specs/widgets/scheduler.md) は設定した時刻・曜日に、指定 Companion (Claude セッション) へプロンプトを自動送信する widget。トリガーは**時刻のみ**、送信先は **Claude のみ**だった。

ここに「**アプリ起動時**にスクリプトを実行したい」「**Terminal セッション**でも実行したい」というニーズが出た。

## 問題

起動時実行を独立した別機能として作ると、プロンプト・送信先・編集 UI・セッション送信 (dispatch) が定時スケジューラとほぼ重複する。本質的には「**実行トリガーが違うだけの同じジョブ**」であり、二重実装は保守コストを生む。送信内容 (prompt) も送信先 (Companion / Terminal) も両者で共通だからだ。

## 決定

スケジューラのジョブを、**トリガー種別**と**送信先種別**を持つ1つのモデルに統合する。

1. **trigger (タグ付きユニオン)**: `scheduled(time, weekdays)` / `onLaunch` / `manual`。種別ごとに必要なフィールドだけを内包する (`time` / `weekdays` は `scheduled` のときだけ存在する)。
2. **target (送信先)**: `claude(companionIndex)` / `terminal`。Terminal は新規タブを起動してコマンドを PTY 送信する。
3. **1 config / 1 UI**: 設定ファイル `.aidea/config/scheduler.json` と popover を共有する。widget 名は「定時スケジューラ」→「**スケジューラ**」に一般化する。
4. **マイグレーション**: 旧スキーマ `{time, weekdays, companionIndex, prompt}` を `trigger: scheduled` + `target: claude` として解釈する後方互換デコーダを入れる。既存ジョブ (朝メモ等) はそのまま動く。
5. **トリガー別の重複管理**: `scheduled` は当日1回 (`lastRun`) ＋未実行通知、`onLaunch` は毎起動 (状態管理なし)、`manual` は都度。
6. **起動時実行のタイミング**: アプリ (リポジトリ) 起動後、セッション基盤の準備が整ってから `onLaunch` ジョブを実行する。

## 結果

- プロンプト・送信先・dispatch・編集 UI を1箇所で共有でき、コード重複が無い。
- **Terminal 送信が定時ジョブにも開放される** (純粋な機能向上)。
- 将来トリガー種別を増やすときに拡張しやすい。
- 既存 `scheduler.json` はマイグレーションにより無変更のまま動く。
- トリガー / 送信先ごとに State・UI が分岐するが、enum (タグ付きユニオン) で表現するため凝集度は保てる。

## 不採用案

| 案 | 理由 |
|---|---|
| **起動時実行を独立した別機能・別 config にする** | prompt・送信先・UI・dispatch が定時とほぼ重複。本質的に同じジョブを二重実装することになり保守コストが高い |
| **既存の定時ジョブに「起動時にも実行」フラグを足すだけ** | トリガーが排他でなくなり「定時かつ起動時」のような曖昧な状態が生まれる。trigger をタグ付きユニオンにする方が状態が明快 |
| **trigger を文字列フィールド + フラットな time/weekdays で持つ** | `time` / `weekdays` が起動時・手動ジョブでも構造上存在し、無効フィールドが残る。タグ付きユニオンの方が「種別ごとに必要なフィールドだけ持つ」凝集度を実現できる |

## 関連

- [docs/specs/widgets/scheduler.md](../specs/widgets/scheduler.md) — 本決定を反映した汎用スケジューラ仕様
- [docs/specs/frontchannels/frontchannel.md](../specs/frontchannels/frontchannel.md) — PTY への送信メカニズム (Claude / Terminal 共通の送信経路)
- [docs/specs/sessions/terminal.md](../specs/sessions/terminal.md) — Terminal セッション (起動時実行の新しい送信先)
- [docs/specs/backchannels/handoff.md](../specs/backchannels/handoff.md) — 未起動セッションを起動して送る挙動の先行実装
