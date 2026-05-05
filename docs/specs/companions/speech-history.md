---
title: コンパニオン Speech 履歴ビュー
description: CompanionEditView の「speech 履歴」ボタンから開くシート。.aidea/backchannels/<n>/speech-*.txt を逆時系列で列挙してテキスト内容を表示する (読み取り専用)
derived_from:
  - docs/specs/backchannels/voicevox.md
syncs_with:
  - docs/specs/companions/companion.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-05
---

# コンパニオン Speech 履歴ビュー

> Companion が書き出した speech ファイルを時系列で確認できる読み取り専用ビュー

---

## 概要

各コンパニオンが VOICEVOX 読み上げ用に書き出した `.aidea/backchannels/<n>/speech-{timestamp}.txt` を一覧表示する。

`CompanionEditView` の「speech 履歴」ボタンから sheet として開く。表示は読み取り専用で、ファイルの編集・削除は行わない。

---

## アクセス経路

```
コンパニオン名ラベルをクリック
  → CompanionEditView (sheet) が開く
    → 「speech 履歴」ボタンをクリック
      → SpeechHistoryView (sheet) が開く
```

---

## 表示仕様

- **取得対象**: `<projectRoot>/.aidea/backchannels/<companionIndex>/speech-*.txt`
- **並び順**: ファイル名 (タイムスタンプ) の降順 — 新しい発話が上に来る
- **表示内容** (1 エントリ):
  - ファイル名 (タイムスタンプを示す識別子として表示)
  - 本文テキスト (1 行目がスピーカーIDなら除いた 2 行目以降)
- **空ファイル / 本文なし**: エントリを表示しない (読み上げ対象外のファイルと同じ扱い)
- **ディレクトリ不在**: 「履歴がありません」と表示 (エラーではない。未使用 Companion は `.aidea/backchannels/<n>/` が存在しないことがある)

## パース

speech ファイルのパースは `SpeechWatcher.parse(_:)` の静的メソッドを再利用する。これにより:
- 1 行目が数値のみ → スピーカーID として除外し 2 行目以降を本文とする
- それ以外 → 全体を本文とする

ファイルの parserロジックを `SpeechWatcher` に集約し二重化しない (DRY)。

---

## 実装コンポーネント

| コンポーネント | ファイル | 責務 |
|---|---|---|
| `SpeechHistoryView` | `Views/Companion/SpeechHistoryView.swift` | speech ファイル読み取りと一覧表示 |
| `CompanionEditView` | `Views/Companion/CompanionEditView.swift` | 「speech 履歴」ボタンと `SpeechHistoryView` sheet 表示 |

---

## 境界

### Always

- ファイルは読み取り専用で表示する (編集・削除しない)
- ディレクトリが不在または空の場合は「履歴がありません」と表示する
- 本文テキストが空のエントリは表示しない
- パースは `SpeechWatcher.parse(_:)` 静的メソッドを使う

### Never

- speech ファイルを削除・移動・編集しない (ADR 0024: 作業履歴として保全)
- ビュー表示のためにファイル監視 (FSEvents) を起動しない (ビュー表示時に一度だけ読み込む)
- `SpeechWatcher` のフロー (読み上げキューへの投入) に干渉しない
