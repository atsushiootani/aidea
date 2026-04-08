---
description: Run TDD workflow — write failing tests, implement, verify. For bugs, use the Prove-It pattern.
---

agent-skills:test-driven-development スキルを呼び出します。

新機能の場合:
1. 期待される振る舞いを記述するテストを書く（FAIL するはず）
2. テストを通すコードを実装する
3. テストをグリーンに保ちつつリファクタする

バグ修正の場合（Prove-It パターン）:
1. バグを再現するテストを書く（必ず FAIL させる）
2. テストが失敗することを確認する
3. 修正を実装する
4. テストが通ることを確認する
5. リグレッション確認のため全テストスイートを実行する

ブラウザ関連の問題については、agent-skills:browser-testing-with-devtools も呼び出して Chrome DevTools MCP で検証します。
