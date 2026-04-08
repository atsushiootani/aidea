# agent-skills

これは agent-skills プロジェクトです — AI コーディングエージェント向けのプロダクショングレードなエンジニアリングスキル集です。

## プロジェクト構造

```
skills/       → コアスキル（ディレクトリごとに SKILL.md）
agents/       → 再利用可能なエージェントペルソナ（code-reviewer、test-engineer、security-auditor）
hooks/        → セッションライフサイクルフック
.claude/commands/ → スラッシュコマンド（/spec, /plan, /build, /test, /review, /code-simplify, /ship）
references/   → 補助チェックリスト（testing、performance、security、accessibility）
docs/         → 各ツール向けセットアップガイド
```

## フェーズ別スキル

**Define:** spec-driven-development
**Plan:** planning-and-task-breakdown
**Build:** incremental-implementation, test-driven-development, context-engineering, frontend-ui-engineering, api-and-interface-design
**Verify:** browser-testing-with-devtools, debugging-and-error-recovery
**Review:** code-review-and-quality, code-simplification, security-and-hardening, performance-optimization
**Ship:** git-workflow-and-versioning, ci-cd-and-automation, deprecation-and-migration, documentation-and-adrs, shipping-and-launch

## 規約

- すべてのスキルは `skills/<name>/SKILL.md` に置く
- `name` と `description` フィールドを含む YAML frontmatter を持つ
- Description は「スキルが何をするか」（三人称）から始まり、その後にトリガー条件（"Use when..."）が続く
- すべてのスキルは Overview、When to Use、Process、Common Rationalizations、Red Flags、Verification を持つ
- References は `references/` に置き、スキルディレクトリ内には置かない
- 補助ファイルは内容が 100 行を超える場合のみ作成する

## コマンド

- `npm test` — 該当しない（これはドキュメントプロジェクト）
- 検証: すべての SKILL.md が `name` と `description` を持つ有効な YAML frontmatter を持つか確認

## 境界

- 常に: 新しいスキルは skill-anatomy.md のフォーマットに従うこと
- 決して: 実行可能なプロセスではなく曖昧な助言のスキルを追加しない
- 決して: スキル間でコンテンツを重複させない — 他のスキルを参照する
