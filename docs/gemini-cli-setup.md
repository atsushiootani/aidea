# Gemini CLI で agent-skills を使う

## セットアップ

### オプション 1: スキルとしてインストール（推奨）

Gemini CLI には、`.gemini/skills/` または `.agents/skills/` ディレクトリ内の `SKILL.md` ファイルを自動検出するネイティブのスキルシステムがあります。各スキルは、タスクに合致したときオンデマンドで有効化されます。

**リポジトリからインストールする：**

```bash
gemini skills install https://github.com/addyosmani/agent-skills.git --path skills
```

**ローカルクローンからインストールする：**

```bash
git clone https://github.com/addyosmani/agent-skills.git
gemini skills install /path/to/agent-skills/skills/
```

**特定のワークスペース専用にインストールする：**

```bash
gemini skills install /path/to/agent-skills/skills/ --scope workspace
```

ワークスペーススコープでインストールされたスキルは `.gemini/skills/`（または `.agents/skills/`）に格納されます。ユーザーレベルのスキルは `~/.gemini/skills/` に格納されます。

インストール後、以下で確認できます。

```
/skills list
```

Gemini CLI はスキル名と説明を自動的にプロンプトに注入します。一致するタスクを認識すると、完全な指示をロードする前にスキルを有効化する許可を求めます。

### オプション 2: GEMINI.md（永続的なコンテキスト）

オンデマンドで有効化するのではなく、永続的なプロジェクトコンテキストとして常にロードしておきたいスキルがある場合は、プロジェクトの `GEMINI.md` に追加します。

```bash
# コアスキルを永続コンテキストとして GEMINI.md を作成
cat /path/to/agent-skills/skills/incremental-implementation/SKILL.md > GEMINI.md
echo -e "\n---\n" >> GEMINI.md
cat /path/to/agent-skills/skills/code-review-and-quality/SKILL.md >> GEMINI.md
```

別ファイルからインポートしてモジュール化することもできます。

```markdown
# プロジェクト指示

@skills/test-driven-development/SKILL.md
@skills/incremental-implementation/SKILL.md
```

`/memory show` でロードされたコンテキストを確認し、変更後は `/memory reload` で再読み込みできます。

> **Skills と GEMINI.md の違い:** Skills は関連するときだけ有効化されるオンデマンドの専門知識で、コンテキストウィンドウをきれいに保ちます。GEMINI.md はプロンプトごとに毎回ロードされる永続的なコンテキストを提供します。フェーズ固有のワークフローには Skills を、常時必要なプロジェクト規約には GEMINI.md を使いましょう。

## 推奨設定

### 常時オン（GEMINI.md）

毎セッションの永続コンテキストとして以下を追加します。

- `incremental-implementation` — 小さく検証可能なスライスで構築
- `code-review-and-quality` — 5 軸レビュー

### オンデマンド（Skills）

関連するときのみ有効化されるよう、以下をスキルとしてインストールします。

- `test-driven-development` — ロジックの実装やバグ修正時に有効化
- `spec-driven-development` — 新規プロジェクトや機能を開始するときに有効化
- `frontend-ui-engineering` — UI を構築するときに有効化
- `security-and-hardening` — セキュリティレビュー中に有効化
- `performance-optimization` — パフォーマンス作業中に有効化

## 使い方のヒント

1. **GEMINI.md より Skills を優先** — Skills はオンデマンドで有効化され、コンテキストウィンドウを集中させます。常にロードしたい場合のみ GEMINI.md にスキルを入れましょう。
2. **スキルの説明が重要** — 各 SKILL.md にはフロントマターに `description` フィールドがあり、Gemini にいつ有効化すべきかを伝えます。このリポジトリの説明はすでに自動有効化のために最適化されています。
3. **レビューにエージェントを使う** — 構造化されたコードレビューを依頼するときは `agents/code-reviewer.md` の内容をコピーしましょう。
4. **References と組み合わせる** — テストやパフォーマンスといった特定の品質領域で作業するとき、`references/` のチェックリストを参照しましょう。
