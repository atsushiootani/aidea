# Agent Skills

**AIコーディングエージェント向けの、プロダクション品質のエンジニアリングスキル集。**

スキルには、シニアエンジニアがソフトウェアを構築する際に用いるワークフロー、品質ゲート、ベストプラクティスがエンコードされています。これらはパッケージ化されており、AIエージェントが開発のあらゆるフェーズで一貫して従えるようになっています。

```
  DEFINE          PLAN           BUILD          VERIFY         REVIEW          SHIP
 ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │ Idea │ ───▶ │ Spec │ ───▶ │ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │
 │Refine│      │  PRD │      │ Impl │      │Debug │      │ Gate │      │ Live │
 └──────┘      └──────┘      └──────┘      └──────┘      └──────┘      └──────┘
  /spec          /plan          /build        /test         /review       /ship
```

---

## コマンド

開発ライフサイクルに対応した7つのスラッシュコマンド。それぞれが適切なスキルを自動で起動します。

| やりたいこと | コマンド | 主な原則 |
|-------------------|---------|---------------|
| 何を作るかを定義する | `/spec` | コードより先に仕様 |
| どう作るかを計画する | `/plan` | 小さく、原子的なタスク |
| インクリメンタルに実装する | `/build` | 一度に1スライス |
| 動作を証明する | `/test` | テストが証拠 |
| マージ前にレビューする | `/review` | コードの健全性を高める |
| コードを簡潔にする | `/code-simplify` | 賢さより明快さ |
| 本番にデプロイする | `/ship` | 速い方が安全 |

スキルは作業内容に応じて自動的に起動もします — APIの設計なら `api-and-interface-design`、UIの構築なら `frontend-ui-engineering` が呼び出されます。

---

## クイックスタート

<details>
<summary><b>Claude Code（推奨）</b></summary>

**マーケットプレイスからインストール:**

```
/plugin marketplace add addyosmani/agent-skills
/plugin install agent-skills@addy-agent-skills
```

**ローカル／開発用:**

```bash
git clone https://github.com/addyosmani/agent-skills.git
claude --plugin-dir /path/to/agent-skills
```

</details>

<details>
<summary><b>Cursor</b></summary>

任意の `SKILL.md` を `.cursor/rules/` にコピーするか、`skills/` ディレクトリ全体を参照してください。詳細は [docs/cursor-setup.md](docs/cursor-setup.ja.md) を参照。

</details>

<details>
<summary><b>Gemini CLI</b></summary>

ネイティブスキルとしてインストールして自動検出させるか、`GEMINI.md` に追加して永続的なコンテキストにします。詳細は [docs/gemini-cli-setup.md](docs/gemini-cli-setup.ja.md) を参照。

**リポジトリからインストール:**

```bash
gemini skills install https://github.com/addyosmani/agent-skills.git --path skills
```

**ローカルクローンからインストール:**

```bash
gemini skills install ./agent-skills/skills/
```

</details>

<details>
<summary><b>Windsurf</b></summary>

スキルの内容を Windsurf のルール設定に追加します。詳細は [docs/windsurf-setup.md](docs/windsurf-setup.ja.md) を参照。

</details>

<details>
<summary><b>GitHub Copilot</b></summary>

`agents/` のエージェント定義を Copilot のペルソナとして、スキルの内容を `.github/copilot-instructions.md` に使用します。詳細は [docs/copilot-setup.md](docs/copilot-setup.ja.md) を参照。

</details>

<details>
<summary><b>Codex / その他のエージェント</b></summary>

スキルは単なる Markdown なので、システムプロンプトや指示ファイルを受け付けるエージェントであれば何でも動作します。詳細は [docs/agent-skills/getting-started.md](docs/agent-skills/getting-started.md) を参照。

</details>

---

## 全19スキル

上のコマンドはエントリポイントです。内部では以下の19スキルが起動されます — いずれもステップ、検証ゲート、合理化防止テーブルを備えた構造化ワークフローです。各スキルを直接参照することもできます。

### Define — 何を作るかを明確にする

| スキル | 概要 | 使う場面 |
|-------|-------------|----------|
| [idea-refine](skills/idea-refine/SKILL.ja.md) | 発散／収束思考を構造化して、曖昧なアイデアを具体的な提案に変える | 探索が必要な粗いコンセプトがある時 |
| [spec-driven-development](skills/spec-driven-development/SKILL.ja.md) | 目的、コマンド、構造、コードスタイル、テスト、境界を網羅したPRDをコード前に書く | 新プロジェクト、機能、大きな変更を始める時 |

### Plan — 分解する

| スキル | 概要 | 使う場面 |
|-------|-------------|----------|
| [planning-and-task-breakdown](skills/planning-and-task-breakdown/SKILL.ja.md) | 仕様を受け入れ基準と依存順序を持つ小さく検証可能なタスクに分解する | 仕様があって実装単位が必要な時 |

### Build — コードを書く

| スキル | 概要 | 使う場面 |
|-------|-------------|----------|
| [incremental-implementation](skills/incremental-implementation/SKILL.ja.md) | 薄い垂直スライス — 実装、テスト、検証、コミット。フィーチャーフラグ、安全なデフォルト、ロールバック容易な変更 | 複数ファイルに及ぶあらゆる変更 |
| [test-driven-development](skills/test-driven-development/SKILL.ja.md) | Red-Green-Refactor、テストピラミッド(80/15/5)、テストサイズ、DRYよりDAMP、Beyonceルール、ブラウザテスト | ロジック実装、バグ修正、挙動変更時 |
| [context-engineering](skills/context-engineering/SKILL.ja.md) | 適切な情報を適切なタイミングでエージェントに与える — ルールファイル、コンテキストパッキング、MCP統合 | セッション開始、タスク切替、出力品質低下時 |
| [frontend-ui-engineering](skills/frontend-ui-engineering/SKILL.ja.md) | コンポーネント設計、デザインシステム、状態管理、レスポンシブ、WCAG 2.1 AA アクセシビリティ | ユーザ向けUIの作成・修正時 |
| [api-and-interface-design](skills/api-and-interface-design/SKILL.ja.md) | 契約優先設計、Hyrumの法則、One-Versionルール、エラーセマンティクス、境界バリデーション | API、モジュール境界、公開インターフェース設計時 |

### Verify — 動作を証明する

| スキル | 概要 | 使う場面 |
|-------|-------------|----------|
| [browser-testing-with-devtools](skills/browser-testing-with-devtools/SKILL.ja.md) | Chrome DevTools MCPでライブランタイムデータ — DOM検査、コンソールログ、ネットワークトレース、パフォーマンスプロファイル | ブラウザで動くものを作る・デバッグする時 |
| [debugging-and-error-recovery](skills/debugging-and-error-recovery/SKILL.ja.md) | 5ステップのトリアージ: 再現、特定、縮小、修正、ガード。Stop-the-line ルール、安全なフォールバック | テスト失敗、ビルド失敗、予期しない挙動時 |

### Review — マージ前の品質ゲート

| スキル | 概要 | 使う場面 |
|-------|-------------|----------|
| [code-review-and-quality](skills/code-review-and-quality/SKILL.ja.md) | 五軸レビュー、変更サイズ(〜100行)、重大度ラベル(Nit/Optional/FYI)、レビュー速度規範、分割戦略 | あらゆる変更のマージ前 |
| [code-simplification](skills/code-simplification/SKILL.ja.md) | チェスタトンの柵、500行ルール、挙動を保ちつつ複雑さを削減 | 動くが読みにくい・保守しにくいコード |
| [security-and-hardening](skills/security-and-hardening/SKILL.ja.md) | OWASP Top 10対策、認証パターン、シークレット管理、依存監査、三層境界システム | ユーザ入力、認証、データ保存、外部連携を扱う時 |
| [performance-optimization](skills/performance-optimization/SKILL.ja.md) | 計測優先 — Core Web Vitals目標、プロファイリング、バンドル分析、アンチパターン検出 | 性能要件がある、またはリグレッションの疑いがある時 |

### Ship — 自信を持ってデプロイ

| スキル | 概要 | 使う場面 |
|-------|-------------|----------|
| [git-workflow-and-versioning](skills/git-workflow-and-versioning/SKILL.ja.md) | トランクベース開発、原子的コミット、変更サイズ(〜100行)、commit-as-save-point パターン | あらゆるコード変更(常時) |
| [ci-cd-and-automation](skills/ci-cd-and-automation/SKILL.ja.md) | Shift Left、Faster is Safer、フィーチャーフラグ、品質ゲートパイプライン、失敗フィードバックループ | ビルド／デプロイパイプラインの構築・変更 |
| [deprecation-and-migration](skills/deprecation-and-migration/SKILL.ja.md) | コード＝負債の発想、強制／推奨の非推奨化、移行パターン、ゾンビコード除去 | 古いシステム除去、ユーザ移行、機能終了時 |
| [documentation-and-adrs](skills/documentation-and-adrs/SKILL.ja.md) | Architecture Decision Records、APIドキュメント、インラインドキュメント標準 — *なぜ*を記録 | アーキ決定、API変更、機能出荷時 |
| [shipping-and-launch](skills/shipping-and-launch/SKILL.ja.md) | プリローンチチェックリスト、フィーチャーフラグライフサイクル、段階的ロールアウト、ロールバック手順、監視セットアップ | 本番デプロイ準備時 |

---

## エージェントペルソナ

焦点を絞ったレビュー用の、事前構成済みスペシャリストペルソナ:

| エージェント | 役割 | 視点 |
|-------|------|-------------|
| [code-reviewer](agents/code-reviewer.ja.md) | シニアスタッフエンジニア | 「スタッフエンジニアならこれを承認するか?」基準の五軸レビュー |
| [test-engineer](agents/test-engineer.ja.md) | QAスペシャリスト | テスト戦略、カバレッジ分析、Prove-Itパターン |
| [security-auditor](agents/security-auditor.ja.md) | セキュリティエンジニア | 脆弱性検出、脅威モデリング、OWASP評価 |

---

## リファレンスチェックリスト

スキルが必要時に引き込むクイックリファレンス:

| リファレンス | 範囲 |
|-----------|--------|
| [testing-patterns.md](references/testing-patterns.ja.md) | テスト構造、命名、モック、React/API/E2E例、アンチパターン |
| [security-checklist.md](references/security-checklist.ja.md) | プリコミットチェック、認証、入力検証、ヘッダー、CORS、OWASP Top 10 |
| [performance-checklist.md](references/performance-checklist.ja.md) | Core Web Vitals目標、フロント／バックチェックリスト、計測コマンド |
| [accessibility-checklist.md](references/accessibility-checklist.ja.md) | キーボードナビ、スクリーンリーダー、ビジュアル、ARIA、テストツール |

---

## スキルの仕組み

すべてのスキルは一貫した構造に従います:

```
┌─────────────────────────────────────────────┐
│  SKILL.md                                   │
│                                             │
│  ┌─ Frontmatter ─────────────────────────┐  │
│  │ name: lowercase-hyphen-name           │  │
│  │ description: Use when [trigger]       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  Overview         → スキルの役割             │
│  When to Use      → トリガー条件             │
│  Process          → 手順                    │
│  Rationalizations → 言い訳と反論            │
│  Red Flags        → 何かおかしい兆候         │
│  Verification     → 証拠要件                │
└─────────────────────────────────────────────┘
```

**主な設計判断:**

- **散文ではなくプロセス。** スキルはエージェントが従うワークフローであり、読むリファレンスではありません。ステップ、チェックポイント、終了条件を持ちます。
- **合理化防止。** 各スキルには、ステップをスキップするためにエージェントが使いがちな言い訳(例: 「テストは後で追加する」)とその反論がまとめられています。
- **検証は譲れない。** すべてのスキルは証拠要件で終わります — テスト合格、ビルド出力、ランタイムデータ。「たぶん正しい」は決して十分ではありません。
- **プログレッシブディスクロージャ。** エントリポイントは `SKILL.md` です。補助リファレンスは必要時にのみ読み込まれ、トークン使用量を最小限に保ちます。

---

## プロジェクト構成

```
agent-skills/
├── skills/                            # 19 個のコアスキル (ディレクトリごとに SKILL.md)
│   ├── idea-refine/                   #   Define
│   ├── spec-driven-development/       #   Define
│   ├── planning-and-task-breakdown/   #   Plan
│   ├── incremental-implementation/    #   Build
│   ├── context-engineering/           #   Build
│   ├── frontend-ui-engineering/       #   Build
│   ├── test-driven-development/       #   Build
│   ├── api-and-interface-design/      #   Build
│   ├── browser-testing-with-devtools/ #   Verify
│   ├── debugging-and-error-recovery/  #   Verify
│   ├── code-review-and-quality/       #   Review
│   ├── code-simplification/          #   Review
│   ├── security-and-hardening/        #   Review
│   ├── performance-optimization/      #   Review
│   ├── git-workflow-and-versioning/   #   Ship
│   ├── ci-cd-and-automation/          #   Ship
│   ├── deprecation-and-migration/     #   Ship
│   ├── documentation-and-adrs/        #   Ship
│   ├── shipping-and-launch/           #   Ship
│   └── using-agent-skills/            #   Meta: このパックの使い方
├── agents/                            # 3 個のスペシャリストペルソナ
├── references/                        # 4 個の補助チェックリスト
├── hooks/                             # セッションライフサイクルフック
├── .claude/commands/                  # 7 個のスラッシュコマンド
└── docs/                              # ツールごとのセットアップガイド
```

---

## なぜ Agent Skills か?

AIコーディングエージェントは既定で最短経路を取ります — それは往々にして仕様、テスト、セキュリティレビュー、そしてソフトウェアを信頼できるものにする実践をスキップすることを意味します。Agent Skills はエージェントに構造化ワークフローを与え、シニアエンジニアが本番コードに持ち込むのと同じ規律を強制します。

各スキルには苦労して得たエンジニアリング判断がエンコードされています: *いつ*仕様を書くか、*何を*テストするか、*どう*レビューするか、*いつ*出荷するか。これらは汎用プロンプトではなく、プロトタイプ品質とプロダクション品質の作業を分ける、意見を持ったプロセス駆動のワークフローです。

スキルには Google のエンジニアリング文化のベストプラクティスが埋め込まれています — [Software Engineering at Google](https://abseil.io/resources/swe-book) や Google の [engineering practices guide](https://google.github.io/eng-practices/) の概念を含みます。API設計の Hyrumの法則、テストの Beyonceルールとテストピラミッド、コードレビューの変更サイズとレビュー速度規範、簡素化のチェスタトンの柵、gitワークフローのトランクベース開発、CI/CDの Shift Left とフィーチャーフラグ、そしてコードを負債として扱う専用の非推奨化スキル。これらは抽象的な原則ではなく、エージェントが従う手順に直接埋め込まれています。

---

## コントリビューション

スキルは **具体的** (曖昧な助言ではなく実行可能なステップ)、**検証可能** (証拠要件付きの明確な終了条件)、**実戦で鍛えられた** (実際のワークフローに基づく)、**最小** (エージェントを導くのに必要なものだけ)、であるべきです。

形式仕様は [docs/agent-skills/skill-anatomy.md](docs/agent-skills/skill-anatomy.md) を、ガイドラインは [CONTRIBUTING.md](CONTRIBUTING.ja.md) を参照してください。

---

## ライセンス

MIT — プロジェクト、チーム、ツールで自由に使用してください。
