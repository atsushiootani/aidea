---
title: Companion Speech 履歴ビュー
description: Companion ごとの speech ファイル (.aidea/backchannels/<n>/speech-*.txt) を一覧表示するビュー仕様
derived_from:
  - docs/specs/backchannels/voicevox.md
syncs_with:
  - docs/specs/companions/companion.md
  - docs/specs/aspects/view-hierarchy.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-05
---

# Companion Speech 履歴ビュー

> Companion が書き出した speech ファイルの履歴を時系列で読める一覧ビュー

[voicevox.md](../backchannels/voicevox.md) が規定するとおり、speech ファイルは読み上げ後も
`.aidea/backchannels/<n>/speech-*.txt` に残る。本ビューはその履歴をユーザが参照できる UI を提供する。

---

## 概要

- `CompanionEditView` に「speech 履歴」ボタンを追加し、`SpeechHistoryView` を sheet として表示する
- `.aidea/backchannels/<companion-index>/speech-*.txt` を読み込み、ファイル名のタイムスタンプ降順で一覧表示する
- スクロール可能なリスト。ファイルが 0 件の場合は「履歴がありません」を表示する

---

## エントリポイント

`CompanionEditView` の「指示書」ボタンの下に「speech 履歴」ボタンを追加する。

- ラベル: `"speech 履歴"` / SF Symbol: `"waveform"` 
- ボタンをタップすると `SpeechHistoryView` の sheet が開く
- `projectRoot` が `nil` (未設定) の場合はボタンを disabled にする

---

## SpeechHistoryView

| 要素 | 詳細 |
|------|------|
| 型 | `SpeechHistoryView` (`struct View`) |
| ファイル | `Views/Companion/SpeechHistoryView.swift` |
| 引数 | `companionIndex: Int`, `projectRoot: URL?` |

### 表示内容

ファイル 1 件 = リスト 1 行として表示する。

| 要素 | 内容 |
|------|------|
| タイムスタンプ | ファイル名 `speech-{timestamp}.txt` の `{timestamp}` 部分を整形表示 (`YYYYMMDDTHHmmss` → `YYYY/MM/DD HH:mm:ss`) |
| 本文 | スピーカーID行 (1行目が整数) を除いたテキスト。[voicevox.md のファイルフォーマット](../backchannels/voicevox.md#ファイルフォーマット) と同じ解析ルールを使う |

### ソート

ファイル名降順 (= タイムスタンプ降順 = 新しい発言が上) で表示する。

### ファイル読み込み

- `.aidea/backchannels/<companionIndex>/speech-*.txt` を `FileManager` で列挙する
- 親ディレクトリが不在 (= speech 書き出し 0 件) の場合は空リストとして扱い「履歴がありません」を表示する
- ファイル読み取りに失敗したエントリは無視する

---

## 境界

### Always
- ファイルは読むだけ。削除・書き込みは行わない
- タイムスタンプ降順で表示する (最新が上)
- スピーカーID行の除外は `SpeechWatcher.parse(_:)` と同じロジックに従う

### Never
- speech ファイルを削除・移動しない (ADR 0024)
- リアルタイム更新 (FSEvents 監視) はしない。sheet を開いた時点のスナップショットを表示する
