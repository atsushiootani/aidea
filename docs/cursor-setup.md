# Cursor で agent-skills を使う

## セットアップ

### オプション 1: ルールディレクトリ（推奨）

Cursor はプロジェクト固有のルール用に `.cursor/rules/` ディレクトリをサポートしています。

```bash
# ルールディレクトリを作成
mkdir -p .cursor/rules

# ルールとして使うスキルをコピー
cp /path/to/agent-skills/skills/test-driven-development/SKILL.md .cursor/rules/test-driven-development.md
cp /path/to/agent-skills/skills/code-review-and-quality/SKILL.md .cursor/rules/code-review-and-quality.md
cp /path/to/agent-skills/skills/incremental-implementation/SKILL.md .cursor/rules/incremental-implementation.md
```

このディレクトリ内のルールは、Cursor のコンテキストに自動的に読み込まれます。

### オプション 2: .cursorrules ファイル

プロジェクトのルートに `.cursorrules` ファイルを作成し、必須スキルをインライン化します。

```bash
# 結合したルールファイルを生成
cat /path/to/agent-skills/skills/test-driven-development/SKILL.md > .cursorrules
echo "\n---\n" >> .cursorrules
cat /path/to/agent-skills/skills/code-review-and-quality/SKILL.md >> .cursorrules
```

### オプション 3: Notepads

Cursor の Notepads 機能を使うと、再利用可能なコンテキストを保存できます。よく使うスキルごとに Notepad を作成しましょう。

1. Cursor → Settings → Notepads を開く
2. "swe: Test-Driven Development" という名前で新しい Notepad を作成
3. `skills/test-driven-development/SKILL.md` の内容を貼り付ける
4. チャットで `@notepad swe: Test-Driven Development` で参照する

## 推奨設定

### 必須スキル（常時ロード）

これらを `.cursor/rules/` に追加します。

1. `test-driven-development.md` — TDD ワークフローと Prove-It パターン
2. `code-review-and-quality.md` — 5 軸レビュー
3. `incremental-implementation.md` — 小さく検証可能なスライスで構築

### フェーズ別スキル（Notepad としてロード）

文脈に応じて使うスキルは Notepad として作成します。

- "swe: Spec Development" → `spec-driven-development/SKILL.md`
- "swe: Frontend UI" → `frontend-ui-engineering/SKILL.md`
- "swe: Security" → `security-and-hardening/SKILL.md`
- "swe: Performance" → `performance-optimization/SKILL.md`

関連タスクで作業する際は `@notepad` で参照しましょう。

## 使い方のヒント

1. **すべてのスキルを一度にロードしない** — Cursor にはコンテキスト制限があります。2〜3 個のスキルをルールとしてロードし、その他は Notepad として保管しましょう。
2. **明示的にスキルを参照する** — Cursor に「この変更には test-driven-development のルールに従って」と伝えて、ロードされたルールを必ず読むようにしましょう。
3. **レビューにエージェントを使う** — `agents/code-reviewer.md` の内容をコピーして、Cursor に「このコードレビューフレームワークを使ってこの diff をレビューして」と指示しましょう。
4. **必要に応じて参照を読み込む** — パフォーマンスに取り組んでいるときは `@notepad performance-checklist` を参照するか、チェックリストの内容を貼り付けましょう。
