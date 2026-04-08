> 🇬🇧 English: [review.md](./review.md) ｜ 🇯🇵 日本語版

---
description: Conduct a five-axis code review — correctness, readability, architecture, security, performance
---

agent-skills:code-review-and-quality スキルを起動します。

現在の変更（ステージング済みまたは直近のコミット）を以下の5軸でレビューします。

1. **正しさ（Correctness）** — スペックに合致しているか？ エッジケースは扱われているか？ テストは十分か？
2. **可読性（Readability）** — 名前は明確か？ ロジックは直線的か？ よく整理されているか？
3. **アーキテクチャ（Architecture）** — 既存パターンに従っているか？ 境界はクリーンか？ 抽象度は適切か？
4. **セキュリティ（Security）** — 入力は検証されているか？ 機密情報は安全か？ 認可チェックは？（security-and-hardening スキルを使用）
5. **パフォーマンス（Performance）** — N+1クエリはないか？ 無制限な処理はないか？（performance-optimization スキルを使用）

指摘は Critical / Important / Suggestion に分類します。
file:line の具体的な参照と修正案を含む構造化レビューを出力します。
