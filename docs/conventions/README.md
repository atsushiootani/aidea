# Aidea Conventions

Aidea のコードを書く際に従うべき規約とガイドライン。
プロダクト仕様 (何を作るか) は [../specs/](../specs/README.md) を参照。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [coding-style.md](./coding-style.md) | Swift 規約 / プロパティラッパ並び順 / コメント方針 / 並行性 |
| [swift.md](./swift.md) | SwiftUI と AppKit (NSView) の使い分け / 閉じ込めルール |
| [design-principles.md](./design-principles.md) | 設計原則 (Tell Don't Ask / SOLID / GRASP 等) |
| [rules.md](./rules.md) | Always / Confirm First / Never — コードレビュー時のチェックリスト |
| [testing.md](./testing.md) | テスト戦略 / 手動確認チェックリスト |

※ docs/ 配下の YAML frontmatter 規約は [../LAYOUT.md](../LAYOUT.md#frontmatter-規約) を参照。

## 読む順番 (初見)

1. [design-principles.md](./design-principles.md) — まず思想を掴む
2. [coding-style.md](./coding-style.md) — 表面的な規約
3. [swift.md](./swift.md) — SwiftUI / NSView の使い分け
4. [testing.md](./testing.md) — テストの方針
5. [rules.md](./rules.md) — Always / Confirm First / Never の具体ルール
