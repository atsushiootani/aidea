---
title: List UI のソート順 (Finder 互換自然順)
description: Filer / Git ファイルツリー / Git diff / Kit など全 List UI のソート規約と Finder 互換の自然順比較ヘルパの SSoT
derived_from: []
syncs_with:
  - docs/specs/tools/filer.md
  - docs/specs/tools/git.md
  - docs/specs/tools/kit.md
  - docs/specs/sessions/git-diff.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-05
---

# List UI のソート順 (Finder 互換自然順)

Aidea の全 List UI は **Finder と同じ自然順**でエントリを並べる。
比較ルールを 1 箇所に集約し、ツール間で並び順の体感を揃えるための SSoT。

## 規約

### 比較関数

- 全 List UI は Finder と同じ自然順比較 (localizedStandardCompare 相当) を使う
  - 大文字小文字を区別しない
  - 数字を含む名前を数値として扱う (例: `file2` < `file10`)
  - ロケール依存の自然順 (日本語の濁点・半濁点や記号も Finder と同等の並び)
- 昇順固定 (降順切替は持たない)
- 単純な辞書順比較 (`<` 演算子等) は使わない

### 種別優先 (ファイル/ディレクトリ等) は付けない

- ファイル/ディレクトリ・USER/PROJECT などの種別はソートキーに含めず、**名前のみで混在させる**
- 例外として、Kit Loader の同名タイブレーク (PROJECT を前に置く) のみ維持する。詳細は [#適用箇所](#適用箇所) を参照

### 共通ヘルパ

自然順昇順比較の共通ヘルパ (`String+NaturalOrder.swift`) を全箇所で使う。内部では Finder と同等の自然順比較を行い、昇順かどうかを返す。

直接比較関数を呼ぶコードは新規追加しない。共通ヘルパを使うことで:

- Aidea のソート規約に従っていることがコード上で一目でわかる
- 将来比較関数を差し替えるときに 1 箇所で済む

## 適用箇所

| 機能 | 並び替えキー | 備考 |
|---|---|---|
| Filer のディレクトリ直下 | エントリ名 | ファイル/ディレクトリ混在 (issue #122) |
| Git ファイルツリー (Working Changes / PR Preview) | エントリ名 | ファイル/ディレクトリ混在 (Filer と完全一致) |
| Git diff のセクション順 | ファイルパス | staged/unstaged のタイブレークは安定ソートで staged 先 |
| Kit / Skills | スキル名 | 同名タイブレーク: PROJECT を前に置く |
| Kit / Commands | コマンド名 | 同名タイブレーク: PROJECT を前に置く |
| Kit / Agents | エージェント名 | 同名タイブレーク: PROJECT を前に置く |
| Kit / MCP Servers | サーバー名 | タイブレーク不要 (USER のみ) |
| Kit / 名前グループ化キー | グループキー | `.`/`-` 前方一致グループ |

新しい List UI を追加するときも本ヘルパに揃える。`<` 演算子による生の文字列比較は使わない。

## 例外: 同名タイブレーク (Kit Loader)

Skills / Commands / Agents は USER と PROJECT スコープが両方マッチした場合に同じ `name` を持つことがあり、
**PROJECT を前に置く** (PROJECT が USER を上書きする関係性を可視化)。自然順で同値判定された場合のみタイブレークが効く:

- 名前が同じ場合: PROJECT スコープを優先する
- 名前が異なる場合: 自然順で昇順ソートする

MCP Servers は USER のみのため、タイブレーク条件を持たず自然順のみ。

## なぜこの規約か

- **Finder と挙動を揃える**: ユーザは macOS Finder の並び順 (数値ソート / 大文字小文字非区別) に慣れているため、Aidea の List もこれに合わせると体感が一致する
- **ツール間で同じ順序**: Filer で見たファイルが、Git パネルや Git diff でも同じ順序で並ぶことを保証する (issue #122 の Filer 対応をワークスペース全体に拡張)
- **共通ヘルパに集約**: 将来 ICU や `String.Comparator` への移行など比較ロジックの差し替えが発生しても 1 箇所で済む
