---
title: .aidea/ の除外設定を .gitignore ではなく .git/info/exclude に書く
description: WorkspaceState.ensureAideaDirectory が共有 .gitignore を自動書き換えする挙動を廃止し、ローカル専用の .git/info/exclude に追記するよう変更する設計判断
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-13
---

# .aidea/ の除外設定を .gitignore ではなく .git/info/exclude に書く

## 背景

`WorkspaceState.ensureAideaDirectory(at:)` は `.aidea/` ディレクトリを生成する際、プロジェクトルートの `.gitignore` に `.aidea/` を自動追記していた。

この挙動が以下の問題を引き起こしていた:

1. **共有 `.gitignore` が汚れる** — チームリポジトリで Aidea 未導入メンバーがいる場合、Aidea が勝手に加えた差分がコミット候補に紛れる
2. **取り消しても再発する** — ユーザーが `.gitignore` から `.aidea/` 行を削除しても、次回プロジェクトを開くたびに復活する
3. **`.aidea/` をコミットしたい運用を妨げる** — `.aidea/claude/` の指示書をリポジトリで共有したいケースがあるが、強制的に ignore されてしまう

## 決定

`.gitignore` への追記を廃止し、**`.git/info/exclude`** に書くよう変更する。

`.git/info/exclude` は git のローカル専用 ignore ファイルであり:

- **共有されない** — `.git/` 配下はリモートにプッシュされない
- **チームに影響しない** — 他メンバーの `.gitignore` を変更しない
- **コミット対象にしたい運用に対応できる** — `.aidea/` を共有したければ `exclude` から行を削除するだけ

`.git/info/` が存在しない場合 (git リポジトリでないプロジェクト) は exclude への追記をスキップする。

## 検討した代替案

| 案 | 概要 | 却下理由 |
|---|---|---|
| A. デフォルト OFF | `.gitignore` 追記をやめるだけ | `.aidea/` が git 管理対象に入るユーザが増える。意図しないコミットリスクあり |
| B. 設定画面でトグル | 現状の挙動を保ちつつ無効化できる | 設定 UI の追加コストが大きい。デフォルト挙動の問題は残る |
| C. 初回のみ追記 | ユーザーが削除したら以後は追記しない | opt-out フラグの永続化実装が必要。`.git/info/exclude` 案より複雑 |
| **D. .git/info/exclude に書く** | ローカル専用 ignore を使う | **採用**。共有 `.gitignore` を一切触らず、追加設定・フラグ不要 |

## 影響

- `WorkspaceState.ensureAideaDirectory(at:)` の実装変更
- `docs/specs/aspects/persistence.md` の仕様記述を更新
- 既存の `.gitignore` に `.aidea/` が追記されていた場合はそのまま残る (Aidea 側から削除はしない)
