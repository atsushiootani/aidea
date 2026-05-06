---
title: Stale Docs 通知 (post-commit hook)
description: Swift ソースファイルが変更されたコミット後に docs/specs が未更新の場合、ターミナルに警告を表示する git post-commit hook の仕様
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/aspects/README.md
last_updated: 2026-05-06
---

# Stale Docs 通知 (post-commit hook)

コミット時に Swift ソースファイルが変更されたにもかかわらず `docs/specs/` が更新されていない場合、コミット直後にターミナルへ警告を表示する仕組み。

---

## 概要

| 項目 | 値 |
|---|---|
| フック種別 | git post-commit |
| スクリプト | `.githooks/post-commit` |
| 通知先 | ターミナル (stdout) |
| ブロック有無 | しない (exit 0 固定・警告のみ) |

---

## 動作フロー

```
git commit
  └─ .githooks/post-commit が起動
       ├─ 変更ファイルを取得 (git diff-tree)
       ├─ .swift ファイルの変更がない → サイレント終了
       ├─ .swift ファイルの変更がある AND docs/specs/ の変更もある → サイレント終了
       └─ .swift ファイルの変更がある AND docs/specs/ の変更がない
            └─ ターミナルに警告を出力して終了 (exit 0)
```

---

## 検出ロジック

1. `git diff-tree --no-commit-id -r --name-only HEAD` でコミット内の変更ファイル一覧を取得する
2. `*.swift` かつ `*Tests*` を含まないファイルを **Swift 変更** として抽出する
3. `docs/specs/` 配下のファイルを **docs 変更** として抽出する
4. Swift 変更があり、かつ docs 変更がゼロの場合に警告を出力する

---

## 警告メッセージ例

```
⚠️  [stale-docs] Swift ファイルが変更されましたが docs/specs/ は更新されていません。

変更された Swift ファイル:
  - Aidea/Aidea/Tools/TerminalTool.swift

specs の更新が必要か確認してください。不要なら無視してください。
```

---

## セットアップ (リポジトリクローン後に一度だけ実行)

```bash
git config core.hooksPath .githooks
```

このコマンドで git が `.git/hooks/` ではなく `.githooks/` をフック検索先として使うようになる。

---

## 設計ポリシー

- **ブロックしない**: 警告のみで `exit 0` とする。コミットワークフローを止めない
- **テストコード除外**: `*Tests*` を含むファイルは通知対象外。テスト追加はドキュメント更新を必須としない
- **false positive を許容**: 「Swift を変えたが docs 更新は不要だった」というケースは存在する。無視してよい旨を警告文に明記する
- **git 管理可能**: `.githooks/` はリポジトリにコミットされるため、クローン後のセットアップは 1 コマンドのみ
