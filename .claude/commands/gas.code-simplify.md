> 🇬🇧 English: [code-simplify.md](./code-simplify.md) ｜ 🇯🇵 日本語版

---
description: Simplify code for clarity and maintainability — reduce complexity without changing behavior
---

agent-skills:code-simplification スキルを起動します。

最近変更されたコード（または指定されたスコープ）について、振る舞いを完全に保ったまま簡素化します。

1. CLAUDE.md を読み、プロジェクトの規約を確認する
2. 対象コードを特定する。広いスコープ指定がない限り直近の変更が対象
3. 触る前に、コードの目的・呼び出し元・エッジケース・テストカバレッジを理解する
4. 簡素化の機会をスキャンする:
   - 深いネスト → ガード節やヘルパー関数の抽出
   - 長い関数 → 責務ごとに分割
   - ネストされた三項演算子 → if/else または switch
   - 汎用的すぎる名前 → 説明的な名前
   - 重複ロジック → 共通関数化
   - デッドコード → 確認の上で削除
5. 各簡素化を段階的に適用する。変更ごとにテストを実行
6. 全テスト通過、ビルド成功、差分がクリーンであることを検証する

簡素化後にテストが失敗したら、その変更を取り消して再考してください。結果のレビューには `code-review-and-quality` を使ってください。
