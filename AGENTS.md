# AGENTS.md

このファイルは、このリポジトリでコードを扱う AI コーディングエージェント（Claude Code、Cursor、Copilot、Antigravity など）へのガイダンスを提供します。

## リポジトリ概要

シニアソフトウェアエンジニア向けの Claude.ai と Claude Code 用スキル集です。スキルはパッケージ化された指示とスクリプトで、Claude やコーディングエージェントの能力を拡張します。

## 新しいスキルを作成する

### ディレクトリ構造

```
skills/
  {skill-name}/           # kebab-case ディレクトリ名
    SKILL.md              # 必須: スキル定義
    scripts/              # 必須: 実行可能スクリプト
      {script-name}.sh    # Bash スクリプト（推奨）
  {skill-name}.zip        # 必須: 配布用にパッケージ化
```

### 命名規約

- **スキルディレクトリ**: `kebab-case`（例: `web-quality`）
- **SKILL.md**: 必ず大文字、必ずこの正確なファイル名
- **スクリプト**: `kebab-case.sh`（例: `deploy.sh`、`fetch-logs.sh`）
- **Zip ファイル**: ディレクトリ名と完全一致: `{skill-name}.zip`

### SKILL.md フォーマット

```markdown
---
name: {skill-name}
description: {このスキルをいつ使うかを 1 文で説明。「アプリをデプロイして」「ログを確認して」のようなトリガーフレーズを含める}
---

# {スキルタイトル}

{スキルが何をするかの簡単な説明。}

## 仕組み

{スキルのワークフローを番号付きリストで説明}

## 使い方

```bash
bash /mnt/skills/user/{skill-name}/scripts/{script}.sh [args]
```

**引数:**
- `arg1` - 説明（デフォルト: X）

**例:**
{2〜3 個の典型的な使い方を示す}

## 出力

{ユーザーが目にする出力例を示す}

## ユーザーへの結果の提示

{結果をユーザーに提示するときに Claude がどうフォーマットすべきかのテンプレート}

## トラブルシューティング

{よくある問題と解決策、特にネットワーク/権限エラー}
```

### コンテキスト効率のためのベストプラクティス

スキルはオンデマンドでロードされます — 起動時にはスキル名と description だけがロードされ、完全な `SKILL.md` はエージェントがそのスキルが関連すると判断したときにのみコンテキストにロードされます。コンテキスト使用量を最小化するには:

- **SKILL.md は 500 行以内に** — 詳細な参照資料は別ファイルに置く
- **具体的な description を書く** — エージェントがいつ有効化すべきか正確に分かるように
- **段階的開示を使う** — 必要なときだけ読まれる補助ファイルを参照する
- **インラインコードよりスクリプトを優先** — スクリプト実行はコンテキストを消費しない（出力のみ消費）
- **ファイル参照は 1 階層まで有効** — SKILL.md から補助ファイルへ直接リンクする

### スクリプト要件

- `#!/bin/bash` シェバンを使う
- fail-fast のため `set -e` を使う
- ステータスメッセージは stderr に書く: `echo "Message" >&2`
- 機械可読な出力（JSON）は stdout に書く
- 一時ファイル用の cleanup trap を含める
- スクリプトパスは `/mnt/skills/user/{skill-name}/scripts/{script}.sh` として参照する

### Zip パッケージの作成

スキルを作成または更新した後:

```bash
cd skills
zip -r {skill-name}.zip {skill-name}/
```

### エンドユーザー向けインストール

ユーザー向けには以下の 2 つのインストール方法を案内しましょう。

**Claude Code:**
```bash
cp -r skills/{skill-name} ~/.claude/skills/
```

**claude.ai:**
プロジェクトナレッジにスキルを追加するか、SKILL.md の内容を会話に貼り付けます。

スキルがネットワークアクセスを必要とする場合、ユーザーに `claude.ai/settings/capabilities` で必要なドメインを追加するよう案内してください。
