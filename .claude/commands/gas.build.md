> 🇬🇧 English: [build.md](./build.md) ｜ 🇯🇵 日本語版

---
description: Implement the next task incrementally — build, test, verify, commit
---

agent-skills:incremental-implementation スキルを agent-skills:test-driven-development とあわせて起動します。

計画から次の未着手タスクを選びます。各タスクについて以下を実施します。

1. タスクの受け入れ基準を読む
2. 関連するコンテキスト（既存コード、パターン、型）を読み込む
3. 期待される振る舞いを表す失敗するテストを書く（RED）
4. テストを通すための最小限のコードを実装する（GREEN）
5. テストスイート全体を実行してリグレッションがないか確認する
6. ビルドを実行してコンパイルを検証する
7. 説明的なメッセージでコミットする
8. タスクを完了マークし、次のタスクへ進む

いずれかのステップが失敗した場合は agent-skills:debugging-and-error-recovery スキルに従ってください。
