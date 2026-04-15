# アクティブ Session の仕組み

Window 内で「現在どの Session にフォーカスしているか」を追跡・切替する仕組み。
Session 概念自体の位置づけは [concept-model.md](./concept-model.md) と [../glossary.md](../glossary.md) を参照。

---

## 基本ルール

- `SessionRegistry.activeSessionID` が Window 全体で **1 つの Active Session** を保持する
- Tab クリック、またはセッションビュー内のクリック (SwiftUI 領域のみ) で切替される
- `activeSessionID` の変更履歴は `activeHistory` に蓄積される (**最大 50 件**)

## Filer ダブルクリック時の挙動

Filer でファイルをダブルクリックすると Preview Session を新規作成するが、
**どのペインに作るか** を履歴から決定する:

1. `activeHistory` をさかのぼる
2. 「**非 Filer ペインの最新 Session**」を探す
3. そのペインに新しい Preview Session タブを作成する

これにより、ユーザーが直前まで操作していたペインに自然に Preview が開く。
