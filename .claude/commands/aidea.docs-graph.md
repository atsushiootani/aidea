---
description: docs/ 配下の frontmatter を読み取り、ドキュメント間の依存関係を Mermaid フローチャートとして出力する
---

# docs グラフ生成

`docs/` 配下の Markdown ファイルが持つ frontmatter (`derived_from` / `syncs_with` / `impacts`) を解析し、ドキュメント間の依存関係を Mermaid フローチャートとして出力する。

仕様: [docs/specs/skills/docs-graph.md](../../docs/specs/skills/docs-graph.md)

## やること

### 1. 対象ファイルの収集

引数を確認する。

- **引数なし**: `docs/` 配下の全 `.md` ファイルを対象にする
- **ファイルパス指定** (例: `docs/specs/aspects/persistence.md`): そのファイルを起点に `--depth N`（デフォルト 1）ホップ以内のノードのみ出力する
- **ディレクトリ指定** (例: `docs/specs/aspects/`): 配下の全 `.md` ファイルを対象にする

`find docs -name "*.md"` でファイル一覧を取得する。

### 2. frontmatter の解析

各ファイルの先頭にある `---` ... `---` ブロック（YAML frontmatter）を読み取り、以下のフィールドを抽出する。

- `derived_from`: 配列。A が `derived_from: [B]` → A が B に依存する（A ← B の方向で解釈。エッジは B →|derived_from|→ A）
- `syncs_with`: 配列。双方向同期。A ↔ B
- `impacts`: 配列。A が `impacts: [C]` → A から C への下流 (A → C)

ワイルドカード (`docs/specs/aspects/*` 等) が含まれる場合は、対象ディレクトリ配下の全 `.md` ファイルに展開して処理する。

frontmatter が存在しないファイルは、孤立ノードとして扱いエッジは張らない。

### 3. エッジの整理

| フィールド | エッジ方向 | Mermaid 記法 | ラベル |
|---|---|---|---|
| `derived_from: [B]` (ファイル A にある) | B →→ A | `B -.->|derived_from| A` | 破線 |
| `impacts: [C]` (ファイル A にある) | A → C | `A -->|impacts| C` | 実線 |
| `syncs_with: [D]` (ファイル A にある) | A ↔ D | `A <-->|syncs| D` | 双方向 |

`syncs_with` は A→B と B→A の双方が宣言されているケースでも、エッジを 1 本に集約する（重複除去）。

### 4. ノード ID の正規化

Mermaid のノード ID に使用できない文字（`/` `.` `-`）を `_` に変換する。

例: `docs/specs/aspects/persistence.md` → `docs_specs_aspects_persistence_md`

ノードのラベル（表示名）はリポジトリルート相対のファイルパスをそのまま使う。長い場合は中間パスを省略して `docs/specs/.../filename.md` と表示してよい。

### 5. Mermaid の出力

以下の形式でコードブロックとして出力する。

```
flowchart TD
    docs_LAYOUT_md["docs/LAYOUT.md"]
    docs_specs_architecture_md["docs/specs/architecture.md"]
    docs_LAYOUT_md -->|impacts| docs_specs_architecture_md
    ...
```

引数でファイル指定した場合は、起点ノードを強調表示する（`style` ディレクティブで背景色を付ける）。

### 6. 補足情報の出力

グラフの後に以下を出力する。

- 総ノード数・総エッジ数
- 孤立ノード（エッジが 0 本のファイル）の一覧（存在する場合）
- エッジが最も多いノード上位 3 件

## 注意

- このスキルはファイルを生成・変更しない（読み取り専用）
- frontmatter のないファイルをエラーとして扱わない
- 出力が大きくなる場合（ノード 50 件以上）は、対象を絞るよう提案する
