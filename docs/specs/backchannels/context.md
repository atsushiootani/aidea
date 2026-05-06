---
title: Backchannel Context 仕様
description: コンパニオンが作業コンテキストを .aidea/backchannels/<companion-index>/context.txt に書き出し・読み込むことで、Aidea 再起動後も記憶を保てる Backchannel 機能の仕様
derived_from:
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-06
---

# Backchannel Context 仕様

## 概要

コンパニオンが作業コンテキスト（現在のタスク・決定事項・次のステップ）を
`.aidea/backchannels/<companion-index>/context.txt` に書き出す機能。
セッション開始時に Claude が自身のコンテキストファイルを読み込むことで、
Aidea を再起動しても各コンパニオンが記憶を維持できる。

speech-*.txt (VOICEVOX 読み上げ用要約) や output-*.txt (全文記録) とは目的が異なり、
Claude が**次のセッションで読み返すための構造化メモ**。

---

## ファイル形式

| 項目 | 仕様 |
|------|------|
| パス | `.aidea/backchannels/<companion-index>/context.txt` |
| エンコード | UTF-8 |
| 形式 | Markdown |
| 内容 | 現在のタスク・最近の決定事項・次のステップ・メモ |

- `<companion-index>`: `0..8` の整数
- タイムスタンプを含まない **固定ファイル名** (1 コンパニオン 1 ファイルで上書き)
- 1 ファイルに作業コンテキストの全体を集約する
- ファイルが存在しない場合は「前のコンテキストなし」として通常起動

### 書式テンプレート

```
# Companion コンテキスト (最終更新: {YYYY-MM-DD HH:MM})

## 現在のタスク
{進行中のタスクの概要}

## 最近の決定事項
{セッション中に下した主な判断}

## 次のステップ
{次のセッションで着手すること}

## メモ
{その他の重要情報}
```

---

## 書き出しタイミング (Claude 側)

- **セッション終了時** (ユーザからの明示的な終わりの挨拶やセッション区切りを検知したとき)
- **大きなタスクの完了時** (長いタスクを終えて区切りが明確なとき)

---

## 読み込みタイミング (Claude 側)

- **セッション開始直後** (instructions.md を読んで指示に従った後)
- `.aidea/backchannels/<companion-index>/context.txt` が存在する場合のみ読み込む
- 読み込んだ内容を自身の記憶として利用し、前回の続きから作業を再開する

---

## 機能宣言 (Claude 側)

`.aidea/claude/context.md` を `instructions.md` から参照することで有効化する (機能宣言チェーン)。`BackchannelSetup` がアプリ起動時にこのファイルを Bundle からコピーする。

---

## Aidea 側の役割

- `BackchannelSetup` が `.aidea/claude/context.md` を Bundle からコピーする (初回のみ)
- Aidea 側でのファイル監視・UI 表示は行わない (コンテキストファイルは Claude が自律管理)
- `.aidea/backchannels/` 配下に書き出されるため、ADR 0024 に従い Aidea はファイルを削除しない

---

## 境界

### Always

- context ファイルは `.aidea/backchannels/<companion-index>/context.txt` (固定名) に書き出す
- ファイルが存在しない場合はスキップし、初回のセッションは通常通り開始する
- 書き出しは上書き (新規作成 + 更新の両方に対応)
- ディレクトリが存在しない場合は Claude 側で作成する

### Never

- タイムスタンプ付きのファイル名は使わない (上書き更新が目的のため)
- output-*.txt や speech-*.txt の代替として使わない (目的が異なる)
- 機密情報 (API キー・パスワード等) を context.txt に書き出さない
