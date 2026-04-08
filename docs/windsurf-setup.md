# Windsurf で agent-skills を使う

## セットアップ

### プロジェクトルール

Windsurf はプロジェクト固有のエージェント指示に `.windsurfrules` を使います。

```bash
# 最重要のスキルをまとめたルールファイルを作成
cat /path/to/agent-skills/skills/test-driven-development/SKILL.md > .windsurfrules
echo "\n---\n" >> .windsurfrules
cat /path/to/agent-skills/skills/incremental-implementation/SKILL.md >> .windsurfrules
echo "\n---\n" >> .windsurfrules
cat /path/to/agent-skills/skills/code-review-and-quality/SKILL.md >> .windsurfrules
```

### グローバルルール

全プロジェクトで使いたいスキルは Windsurf のグローバルルールに追加します。

1. Windsurf → Settings → AI → Global Rules を開く
2. よく使うスキルの内容を貼り付ける

## 推奨設定

コンテキスト制限内に収めるため、`.windsurfrules` は 2〜3 個の必須スキルに絞りましょう。

```
# .windsurfrules
# このプロジェクトに必須の agent-skills

[test-driven-development SKILL.md を貼り付け]

---

[incremental-implementation SKILL.md を貼り付け]

---

[code-review-and-quality SKILL.md を貼り付け]
```

## 使い方のヒント

1. **選択的に** — Windsurf のコンテキストは限られています。最大の品質ギャップに対処するスキルを選びましょう。
2. **会話で参照する** — 特定フェーズの作業中は、該当スキルの内容を追加でチャットに貼り付けましょう（例: 認証機能を作るときは `security-and-hardening` を貼る）。
3. **リファレンスをチェックリストとして使う** — `references/security-checklist.md` を貼り付けて、各項目を検証するよう Windsurf に依頼しましょう。
