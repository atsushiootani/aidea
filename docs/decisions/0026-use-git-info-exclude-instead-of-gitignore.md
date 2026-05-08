---
title: .aidea/ の除外設定を .git/info/exclude に書き、共有 .gitignore は触らない
description: ensureAideaDirectory が .gitignore を自動書き換えする挙動をやめ、.git/info/exclude を使うことで共有リポジトリへの副作用をゼロにする設計判断
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-08
---

# .aidea/ の除外設定を .git/info/exclude に書き、共有 .gitignore は触らない

## 背景

`WorkspaceState.ensureAideaDirectory(at:)` は、プロジェクトを開くたびに `.gitignore` に `.aidea/` エントリを自動追記していた。これには以下の問題があった:

1. **ユーザーの意思を無視した書き換え**: チームで共有する `.gitignore` に Aidea 由来の行が混入し、コミット前に毎回手動で戻す運用になる
2. **取り消しても再発**: ユーザーが `.aidea/` 行を削除しても次回起動時に復活する
3. **`.aidea/` をコミットしたい運用を妨げる**: 例: `.aidea/claude/` の指示書をチームで共有したい場合でも強制 ignore される

## 決定

`.git/info/exclude` に `.aidea/` を追記する。共有 `.gitignore` は一切変更しない。

## 理由

- `.git/info/exclude` は **ローカルのみ有効** な gitignore であり、リポジトリに含まれない
- チームメンバーの `.gitignore` に一切干渉しないため、「Aidea 未導入メンバーへの影響ゼロ」
- `.aidea/` をコミット対象にしたい運用 (チームで指示書を共有する等) でも、ユーザーが `.git/info/exclude` を手動編集するだけで対応できる
- opt-out フラグや設定トグルが不要で、実装がシンプルになる
- `.git/info/` ディレクトリが存在しない (git リポジトリでない) 場合は何もしない (安全)

## 却下した代替案

| 案 | 理由 |
|---|---|
| **A. デフォルト OFF** | `.aidea/` がコミット候補に紛れる可能性が残り、ユーザーの手間が増える |
| **B. 設定トグル** | 追加 UI と設定管理が必要で複雑になる |
| **C. 初回のみ追記 (opt-out フラグ)** | フラグの保存先管理が必要; `.gitignore` を一度でも変更する問題は残る |

## 影響

- `WorkspaceState.ensureAideaDirectory(at:)` が `.gitignore` ではなく `.git/info/exclude` に書くよう変更する
- `.git/info/` が存在しないプロジェクトでは exclude 追記をスキップする (git リポジトリでないため)
- 既存の `.gitignore` に書き込まれていた `.aidea/` エントリは自動では削除しない (ユーザーが手動で除去可)
