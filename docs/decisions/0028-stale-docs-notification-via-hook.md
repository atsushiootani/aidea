---
title: "0028: docs/specs の更新漏れ検出に git post-commit hook を採用"
description: Swift ファイル変更コミット時に docs/specs 未更新を検出する仕組みとして git post-commit hook を選択した判断の記録
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-20
---

# 0028: docs/specs の更新漏れ検出に git post-commit hook を採用

**日付**: 2026-05-20

## 背景

Swift コードを変更したコミットで `docs/specs/` の更新が漏れるケースが発生していた。
issue #64 では gitnexus のような「コミット時に docs が古くなったことを push 式で通知する仕組み」を Aidea でも実現できないか検討した。

## 決定

**git post-commit hook** (`.githooks/post-commit`) を採用する。

- コミット直後に実行され、変更ファイル一覧から Swift 変更と docs/specs 変更の有無を比較する
- 不一致を検出した場合はターミナルへ警告メッセージを出力する（コミットはブロックしない）
- `.githooks/` をリポジトリ管理することで、チーム全員が同一スクリプトを使用できる

## 採用理由

| 観点 | post-commit hook |
|---|---|
| 開発者への即時フィードバック | コミット直後にターミナルへ表示されるため気づきやすい |
| 非破壊 | exit 0 でコミット自体をブロックしない。警告のみ |
| 実装コスト | シェルスクリプト数行で完結。外部依存なし |
| リポジトリ管理 | `.githooks/` をコミット管理でき、チーム内で統一できる |

## 不採用案

| 案 | 不採用理由 |
|---|---|
| pre-commit hook | コミットをブロックするため、ドキュメント更新が間に合わない場合の開発体験が悪い |
| CI での検出 | フィードバックが遅い（push 後）。ローカルでの即時気づきを優先した |
| Aidea アプリ内通知 | 実装コストが高い。まず軽量な仕組みで始める |
| commit-msg hook | コミットメッセージとは無関係のチェックで意味論が合わない |

## トレードオフ

- **手動セットアップが必要**: `git config core.hooksPath .githooks` を各開発者が一度実行する必要がある。git の仕様上、hooks を自動適用する方法はない
- **偽陰性あり**: リファクタリングなど仕様変更を伴わない Swift 変更でも警告が出る。exit 0 でブロックしないため許容する
- **テストファイル除外**: テストのみ変更した場合は仕様変更を伴わないケースが多いため警告しない
