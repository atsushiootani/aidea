---
title: Backchannel Output 仕様
description: Claude がレスポンスを .aidea/backchannels/<companion-index>/output-{timestamp}.txt に書き出し、Aidea が出力履歴として蓄積する Backchannel メッセージ種別の仕様
derived_from:
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-05
---

# Backchannel Output 仕様

## 概要

Claude がレスポンスのテキストを `.aidea/backchannels/<companion-index>/output-{timestamp}.txt` に書き出す機能。speech が VOICEVOX 読み上げ用の要約を書くのに対し、output はテキスト形式での応答全文を書き出す。Aidea 再起動後もファイルが残るため、コンパニオンの作業記録として利用できる。

---

## ファイル形式

| 項目 | 仕様 |
|------|------|
| パターン | `.aidea/backchannels/<companion-index>/output-{timestamp}.txt` |
| エンコード | UTF-8 |
| 形式 | プレーンテキスト |
| 内容 | Claude のレスポンス全文 |

- `<companion-index>`: `0..8` の整数 (BackchannelPath の検証規約に準拠)
- `{timestamp}`: ISO 8601 コンパクト形式 (`YYYYMMDDTHHmmss`)
- 1 ファイル 1 レスポンス (追記ではなく新規作成)
- ファイルは削除しない (ADR 0024: 作業履歴として保全)

---

## ファイル監視 (Aidea 側)

出力監視コンポーネント (OutputWatcher) が `.aidea/backchannels/` を FSEvents で再帰監視し、`output-*.txt` ファイルを検知したら出力状態管理コンポーネントに通知する。

| チェック項目 | 動作 |
|-------------|------|
| 親ディレクトリが `0..8` 以外 | 警告ログのみで無視 |
| ファイルが空 | スキップ (ログなし) |
| 正常検知 | 出力状態管理コンポーネントに通知する |

### 出力状態管理 (OutputState)

通知を受け取り、コンパニオン別の出力履歴をインデックスをキーとして蓄積する。状態変更は UI に自動伝播する。

---

## 書き出しタイミング (Claude 側)

Claude は以下のタイミングで output ファイルを書き出す。

- レスポンス完了時

---

## 機能宣言 (Claude 側)

`.aidea/claude/output.md` を `instructions.md` から参照することで有効化する (機能宣言チェーン)。アプリ起動時の初回セットアップ処理がこのファイルを Bundle からコピーする。

---

## 境界

### Always

- output ファイルは `.aidea/backchannels/<companion-index>/output-{timestamp}.txt` に書き出す
- Aidea 側でファイルを削除しない (ADR 0024)
- 出力監視コンポーネントは親ディレクトリ名を検証してから処理する

### Never

- speech ファイル (`speech-*.txt`) の代替として output ファイルを使わない (用途が異なる)
- output ファイルに VOICEVOX 向けのスピーカーID 行を含めない
