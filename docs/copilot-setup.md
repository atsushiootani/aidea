# GitHub Copilot で agent-skills を使う

## セットアップ

### Copilot Instructions

Copilot は、リポジトリ内の `.github/skills`、`.claude/skills`、または `.agents/skills` ディレクトリを使ってエージェントスキルを作成することをサポートしています。

```bash
mkdir -p .github

# 必須スキルのファイルを作成
cat /path/to/agent-skills/skills/test-driven-development/SKILL.md > .github/skills/test-driven-development/SKILL.md
cat /path/to/agent-skills/skills/code-review-and-quality/SKILL.md > .github/skills/code-review-and-quality/SKILL.md
```

詳しくは [Creating agent skills for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills) を参照してください。

### Agent Personas (agents.md)

Copilot は専門化されたエージェントペルソナをサポートしています。agent-skills のエージェントを使いましょう。

```bash
# エージェント定義をコピー
cp /path/to/agent-skills/agents/code-reviewer.md .github/agents/code-reviewer.md
cp /path/to/agent-skills/agents/test-engineer.md .github/agents/test-engineer.md
cp /path/to/agent-skills/agents/security-auditor.md .github/agents/security-auditor.md
```

Copilot Chat でエージェントを呼び出します。

- `@code-reviewer この PR をレビューして`
- `@test-engineer このモジュールのテストカバレッジを分析して`
- `@security-auditor このエンドポイントの脆弱性をチェックして`

### Custom Instructions（ユーザーレベル）

すべてのリポジトリで使いたいスキルがある場合：

1. VS Code → Settings → GitHub Copilot → Custom Instructions を開く
2. よく使うスキルの要約を追加する

## 推奨設定

### .github/copilot-instructions.md

GitHub Copilot は `.github/copilot-instructions.md` によるプロジェクトレベルの指示をサポートしています。

```markdown
# プロジェクトコーディング規約

## テスト
- コードの前にテストを書く（TDD）
- バグ修正の場合: 先に失敗するテストを書いてから修正する（Prove-It パターン）
- テスト階層: unit > integration > e2e（挙動を捕捉できる最も低いレベルを使う）
- 変更ごとに `npm test` を実行する

## コード品質
- 5 軸でレビューする: 正しさ、読みやすさ、アーキテクチャ、セキュリティ、パフォーマンス
- すべての PR は lint、型チェック、テスト、ビルドを通過しなければならない
- コードやバージョン管理にシークレットを入れない

## 実装
- 小さく検証可能な単位で構築する
- 各単位: 実装 → テスト → 検証 → コミット
- フォーマット変更と挙動変更を混ぜない

## 境界
- 常に: コミット前にテスト実行、ユーザー入力を検証
- 先に確認: データベーススキーマ変更、新しい依存
- 決して: シークレットをコミット、失敗するテストを削除、検証をスキップ
```

### 専門エージェント

Copilot Chat でターゲットを絞ったレビューワークフローのためにエージェントを使いましょう。

## 使い方のヒント

1. **指示は簡潔に保つ** — Copilot の指示は焦点が絞られているときに最も効果的です。スキルファイルの全文を含めるのではなく、重要なルールを要約しましょう。
2. **レビューにエージェントを使う** — code-reviewer、test-engineer、security-auditor エージェントは Copilot のエージェントモデル向けに設計されています。
3. **チャットで参照する** — 特定のフェーズで作業する際は、関連するスキルの内容を Copilot Chat に貼り付けてコンテキストとして使いましょう。
4. **PR レビューと組み合わせる** — code-reviewer エージェントペルソナを使って Copilot に PR をレビューさせるよう設定しましょう。
