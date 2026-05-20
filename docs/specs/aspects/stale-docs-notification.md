---
title: Stale Docs 通知 (post-commit hook)
description: Swift ファイル変更コミット時に docs/specs 未更新を検出して開発者へ警告する仕組みの仕様
derived_from:
  - docs/decisions/0028-stale-docs-notification-via-hook.md
syncs_with:
  - docs/specs/aspects/README.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-20
---

# Stale Docs 通知 (post-commit hook)

## 目的

Swift コードを変更したコミットで `docs/specs/` が更新されていない場合に、開発者へターミナル上で警告を出力する。「気づきベース」の通知であり、コミットをブロックしない。

## 動作仕様

### トリガー

`git commit` 完了後に実行される **post-commit フック**。

### 検出ロジック

以下の条件を **両方** 満たすときに警告を出力する:

1. コミットに非テスト `.swift` ファイルの変更が含まれる
   - テストファイル (`*Tests.swift` / `Tests/` 配下) は対象外
2. コミットに `docs/specs/` 配下の変更が含まれない

### 出力

標準エラー出力へ警告メッセージを表示する。コミット自体は成功する (exit 0)。

```
⚠️  [Aidea] Swift ファイルが変更されましたが、docs/specs/ の更新がありません。
   仕様変更を伴う場合は docs/specs/ も更新してください。
```

## セットアップ

- フックスクリプトは `.githooks/post-commit` に配置する
- 初回のみ以下を実行してフックを有効化する:
  ```sh
  git config core.hooksPath .githooks
  ```
- チームメンバー各自が一度だけ実行する必要がある（git の仕様上、hooks は自動適用されない）

## スコープ

### 含むもの

- コミット単位での Swift 変更 vs docs/specs 変更の不一致検出
- 警告メッセージのターミナル表示（コミットはブロックしない）

### 含まないもの

- CI での自動検出（別途検討）
- Aidea アプリ内への通知（別途検討）
- `docs/specs/` 以外のドキュメント（`docs/decisions/` 等）の更新検出
