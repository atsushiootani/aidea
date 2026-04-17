> 🇬🇧 English: [plan.md](./plan.md) ｜ 🇯🇵 日本語版

---
description: Break work into small verifiable tasks with acceptance criteria and dependency ordering
---

agent-skills:planning-and-task-breakdown スキルを起動します。

既存のスペック（docs/specs/ 配下と docs/foundation/vision.md）と関連するコードベースの該当箇所を読みます。その上で:

1. プランモードに入る — 読み取り専用、コード変更なし
2. コンポーネント間の依存グラフを特定する
3. 作業を縦に切る（水平レイヤーではなく、1タスクで完結する1パスを作る）
4. 各タスクに受け入れ基準と検証手順を書く
5. フェーズ間にチェックポイントを設ける
6. プランを人間レビュー向けに提示する

プランは tasks/plan.md に、タスク一覧は tasks/todo.md に保存します。
