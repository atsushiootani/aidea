# agent-skills 入門

agent-skills は、Markdown 形式の指示を受け付ける任意の AI コーディングエージェントで動作します。このガイドは普遍的なアプローチを扱います。ツール固有のセットアップは、専用ガイドを参照してください。

## スキルの仕組み

各スキルは、特定のエンジニアリングワークフローを記述した Markdown ファイル（`SKILL.md`）です。エージェントのコンテキストにロードされると、エージェントはそのワークフローに従います — 検証手順、回避すべきアンチパターン、終了条件を含めて。

**スキルはリファレンス文書ではありません。** エージェントが従うステップバイステップのプロセスです。

## クイックスタート（任意のエージェント）

### 1. リポジトリをクローン

```bash
git clone https://github.com/addyosmani/agent-skills.git
```

### 2. スキルを選ぶ

`skills/` ディレクトリを参照します。各サブディレクトリには以下を含む `SKILL.md` があります。

- **When to use** — このスキルが該当するトリガー
- **Process** — ステップバイステップのワークフロー
- **Verification** — 作業完了の確認方法
- **Common rationalizations** — エージェントがステップをスキップするために使う言い訳
- **Red flags** — スキルが破られている兆候

### 3. スキルをエージェントにロード

該当する `SKILL.md` の内容をエージェントのシステムプロンプト、ルールファイル、または会話にコピーします。最も一般的なアプローチは：

**システムプロンプト:** セッションの最初にスキル内容を貼り付ける。

**ルールファイル:** プロジェクトのルールファイル（CLAUDE.md、.cursorrules など）にスキル内容を追加する。

**会話:** 指示を出すときにスキルを参照する。「この変更には test-driven-development プロセスに従って」など。

### 4. 発見のためにメタスキルを使う

`using-agent-skills` スキルをロードした状態で始めましょう。タスクの種類を適切なスキルにマッピングするフローチャートが含まれています。

## 推奨セットアップ

### 最小構成（ここから始める）

ルールファイルに 3 つの必須スキルをロードします。

1. **spec-driven-development** — 何を作るかを定義する
2. **test-driven-development** — それが機能することを証明する
3. **code-review-and-quality** — マージ前に品質を検証する

これら 3 つは、AI 支援開発における最も重大な品質ギャップをカバーします。

### フルライフサイクル

包括的にカバーしたい場合は、フェーズごとにスキルをロードします。

```
プロジェクト開始時:  spec-driven-development → planning-and-task-breakdown
開発中:              incremental-implementation + test-driven-development
マージ前:            code-review-and-quality + security-and-hardening
デプロイ前:          shipping-and-launch
```

### コンテキスト依存のロード

すべてのスキルを一度にロードしないでください — コンテキストの無駄遣いです。現在のタスクに関連するスキルだけをロードします。

- UI 作業中？ `frontend-ui-engineering` をロード
- デバッグ中？ `debugging-and-error-recovery` をロード
- CI を構築中？ `ci-cd-and-automation` をロード

## スキルの構造

すべてのスキルは同じ構造に従います。

```
YAML frontmatter (name, description)
├── Overview（概要） — このスキルが何をするか
├── When to Use（使うとき） — トリガーと条件
├── Core Process（コアプロセス） — ステップバイステップのワークフロー
├── Examples（例） — コードサンプルとパターン
├── Common Rationalizations（よくある合理化） — 言い訳と反論
├── Red Flags（レッドフラグ） — スキルが破られているサイン
└── Verification（検証） — 終了条件のチェックリスト
```

完全な仕様は [skill-anatomy.ja.md](skill-anatomy.ja.md) を参照してください。

## エージェントを使う

`agents/` ディレクトリには事前設定されたエージェントペルソナがあります。

| Agent | Purpose |
|-------|---------|
| `code-reviewer.md` | 5 軸コードレビュー |
| `test-engineer.md` | テスト戦略と作成 |
| `security-auditor.md` | 脆弱性検出 |

専門レビューが必要なときにエージェント定義をロードします。たとえば、コーディングエージェントに「code-reviewer エージェントペルソナを使ってこの変更をレビューして」と依頼し、エージェント定義を提供します。

## コマンドを使う

`.claude/commands/` ディレクトリには Claude Code 用のスラッシュコマンドがあります。

| Command | Skill Invoked |
|---------|---------------|
| `/spec` | spec-driven-development |
| `/plan` | planning-and-task-breakdown |
| `/build` | incremental-implementation + test-driven-development |
| `/test` | test-driven-development |
| `/review` | code-review-and-quality |
| `/ship` | shipping-and-launch |

## References を使う

`references/` ディレクトリには補助的なチェックリストがあります。

| Reference | Use With |
|-----------|----------|
| `testing-patterns.md` | test-driven-development |
| `performance-checklist.md` | performance-optimization |
| `security-checklist.md` | security-and-hardening |
| `accessibility-checklist.md` | frontend-ui-engineering |

スキルがカバーしている範囲を超える詳細なパターンが必要なときに References をロードしましょう。

## ヒント

1. 些細でない作業には **spec-driven-development から始める**
2. コードを書くときは **常に test-driven-development をロードする**
3. **検証手順をスキップしない** — それこそがスキルの目的です
4. **スキルは選択的にロードする** — コンテキストが多ければ良いというものではありません
5. **レビューにエージェントを使う** — 異なる視点が異なる問題を捕まえます
