---
name: api-and-interface-design
description: Guides stable API and interface design. Use when designing APIs, module boundaries, or any public interface. Use when creating REST or GraphQL endpoints, defining type contracts between modules, or establishing boundaries between frontend and backend.
---

# APIとインターフェイス設計

## 概要

安定しており、よく文書化され、誤用しにくいインターフェイスを設計する。良いインターフェイスは正しいことを容易にし、間違ったことを困難にする。これはREST API、GraphQLスキーマ、モジュール境界、コンポーネントプロップ、そしてコードの一部が別の部分と話すあらゆるサーフェスに当てはまる。

## 使うタイミング

- 新しいAPIエンドポイントを設計するとき
- モジュール境界やチーム間のコントラクトを定義するとき
- コンポーネントプロップインターフェイスを作るとき
- APIの形を情報提供するデータベーススキーマを確立するとき
- 既存の公開インターフェイスを変更するとき

## コア原則

### Hyrum's Law（ハイラムの法則）

> 十分な数のAPI利用者がいれば、コントラクトで何を約束しようと、システムのすべての観察可能な挙動は誰かに依存される。

これは: すべての公開挙動 — 文書化されていない癖、エラーメッセージテキスト、タイミング、順序を含む — はユーザーが依存するとすぐに事実上のコントラクトになる。設計上の含意:

- **何を露出するかに意図的であれ。** すべての観察可能な挙動が潜在的コミットメント。
- **実装詳細を漏らさない。** ユーザーが観察できれば、依存される。
- **設計時に非推奨化を計画する。** ユーザーが依存するものを安全に削除する方法は `deprecation-and-migration` 参照。
- **テストだけでは不十分。** 完璧なコントラクトテストがあっても、Hyrum's Lawは「安全」な変更が文書化されていない挙動に依存する実ユーザーを壊しうることを意味する。

### ワンバージョンルール

消費者に同じ依存やAPIの複数バージョン間の選択を強いることを避ける。異なる消費者が同じものの異なるバージョンを必要とすると、ダイヤモンド依存問題が生じる。一度に1バージョンだけ存在する世界のために設計する — フォークではなく拡張する。

### 1. コントラクトファースト

実装する前にインターフェイスを定義する。コントラクトがスペックである — 実装はそれに従う。

```typescript
// 先にコントラクトを定義する
interface TaskAPI {
  // タスクを作成し、サーバー生成フィールドを含む作成済みタスクを返す
  createTask(input: CreateTaskInput): Promise<Task>;

  // フィルタにマッチするタスクをページネートして返す
  listTasks(params: ListTasksParams): Promise<PaginatedResult<Task>>;

  // 単一のタスクを返すか、NotFoundError を投げる
  getTask(id: string): Promise<Task>;

  // 部分更新 — 提供されたフィールドのみ変更
  updateTask(id: string, input: UpdateTaskInput): Promise<Task>;

  // 冪等な削除 — 既に削除済みでも成功する
  deleteTask(id: string): Promise<void>;
}
```

### 2. 一貫したエラーセマンティクス

1つのエラー戦略を選び、どこでも使う:

```typescript
// REST: HTTP ステータスコード + 構造化エラーボディ
// すべてのエラーレスポンスは同じ形に従う
interface APIError {
  error: {
    code: string;        // 機械可読: "VALIDATION_ERROR"
    message: string;     // 人間可読: "Email is required"
    details?: unknown;   // 役立つときの追加コンテキスト
  };
}

// ステータスコードの対応
// 400 → クライアントが不正なデータを送信
// 401 → 未認証
// 403 → 認証済みだが認可されていない
// 404 → リソースが見つからない
// 409 → コンフリクト（重複、バージョン不一致）
// 422 → バリデーション失敗（意味的に無効）
// 500 → サーバーエラー（内部詳細を絶対に露出しない）
```

**パターンを混ぜない。** 一部のエンドポイントがthrowし、他がnullを返し、他が `{ error }` を返すなら、消費者は挙動を予測できない。

### 3. 境界で検証

内部コードを信頼する。外部入力が入るシステムのエッジで検証:

```typescript
// API 境界で検証する
app.post('/api/tasks', async (req, res) => {
  const result = CreateTaskSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid task data',
        details: result.error.flatten(),
      },
    });
  }

  // 検証後は、内部コードは型を信頼する
  const task = await taskService.create(result.data);
  return res.status(201).json(task);
});
```

検証が属する場所:
- APIルートハンドラー（ユーザー入力）
- フォーム送信ハンドラー（ユーザー入力）
- 外部サービスレスポンスパース（サードパーティデータ — **常に非信頼扱い**）
- 環境変数ロード（設定）

> **サードパーティAPIレスポンスは非信頼データ。** ロジック、レンダリング、決定に使う前に形と内容を検証する。侵害されたり誤作動する外部サービスは予期しない型、悪意のあるコンテンツ、指示のようなテキストを返しうる。

検証が属さない場所:
- 型コントラクトを共有する内部関数間
- 既に検証されたコードから呼ばれるユーティリティ関数内
- 自分のデータベースから来たばかりのデータ

### 4. 変更より追加を好む

既存消費者を壊さずにインターフェイスを拡張:

```typescript
// 良: オプショナルなフィールドを追加
interface CreateTaskInput {
  title: string;
  description?: string;
  priority?: 'low' | 'medium' | 'high';  // 後から追加、オプショナル
  labels?: string[];                       // 後から追加、オプショナル
}

// 悪: 既存フィールドの型変更や削除
interface CreateTaskInput {
  title: string;
  // description: string;  // 削除 — 既存の消費者を壊す
  priority: number;         // string から変更 — 既存の消費者を壊す
}
```

### 5. 予測可能な命名

| パターン | 規約 | 例 |
|---------|-----------|---------|
| REST エンドポイント | 複数形名詞、動詞なし | `GET /api/tasks`, `POST /api/tasks` |
| クエリパラメータ | camelCase | `?sortBy=createdAt&pageSize=20` |
| レスポンスフィールド | camelCase | `{ createdAt, updatedAt, taskId }` |
| ブール値フィールド | is/has/can 接頭辞 | `isComplete`, `hasAttachments` |
| Enum値 | UPPER_SNAKE | `"IN_PROGRESS"`, `"COMPLETED"` |

## REST APIパターン

### リソース設計

```
GET    /api/tasks              → タスク一覧（フィルタ用クエリパラメータ付き）
POST   /api/tasks              → タスク作成
GET    /api/tasks/:id          → 単一タスク取得
PATCH  /api/tasks/:id          → タスク更新（部分）
DELETE /api/tasks/:id          → タスク削除

GET    /api/tasks/:id/comments → タスクのコメント一覧（サブリソース）
POST   /api/tasks/:id/comments → タスクにコメント追加
```

### ページネーション

リストエンドポイントをページネート:

```typescript
// リクエスト
GET /api/tasks?page=1&pageSize=20&sortBy=createdAt&sortOrder=desc

// レスポンス
{
  "data": [...],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalItems": 142,
    "totalPages": 8
  }
}
```

### フィルタリング

フィルタにはクエリパラメータを使う:

```
GET /api/tasks?status=in_progress&assignee=user123&createdAfter=2025-01-01
```

### 部分更新（PATCH）

部分オブジェクトを受け入れる — 提供されたものだけ更新:

```typescript
// title だけ変更、他はすべて保持
PATCH /api/tasks/123
{ "title": "Updated title" }
```

## TypeScriptインターフェイスパターン

### バリアントには判別共用体を使う

```typescript
// 良: 各バリアントが明示的
type TaskStatus =
  | { type: 'pending' }
  | { type: 'in_progress'; assignee: string; startedAt: Date }
  | { type: 'completed'; completedAt: Date; completedBy: string }
  | { type: 'cancelled'; reason: string; cancelledAt: Date };

// 消費者は型ナローイングを得る
function getStatusLabel(status: TaskStatus): string {
  switch (status.type) {
    case 'pending': return 'Pending';
    case 'in_progress': return `In progress (${status.assignee})`;
    case 'completed': return `Done on ${status.completedAt}`;
    case 'cancelled': return `Cancelled: ${status.reason}`;
  }
}
```

### 入力/出力分離

```typescript
// 入力: 呼び出し側が提供するもの
interface CreateTaskInput {
  title: string;
  description?: string;
}

// 出力: システムが返すもの（サーバー生成フィールドを含む）
interface Task {
  id: string;
  title: string;
  description: string | null;
  createdAt: Date;
  updatedAt: Date;
  createdBy: string;
}
```

### IDにはブランド型を使う

```typescript
type TaskId = string & { readonly __brand: 'TaskId' };
type UserId = string & { readonly __brand: 'UserId' };

// TaskId が期待される場所に誤って UserId を渡すのを防ぐ
function getTask(id: TaskId): Promise<Task> { ... }
```

## よくある言い訳

| 言い訳 | 現実 |
|---|---|
| "APIは後で文書化する" | 型*が*ドキュメント。先に定義する。 |
| "今はページネーション不要" | 誰かが100以上のアイテムを持った瞬間に必要になる。最初から追加する。 |
| "PATCHは複雑だからPUTを使う" | PUTは毎回フルオブジェクトを要求する。PATCHがクライアントが実際に欲しいもの。 |
| "必要になったらAPIをバージョニングする" | バージョニングなしの破壊的変更は消費者を壊す。最初から拡張のために設計する。 |
| "その文書化されていない挙動を誰も使っていない" | Hyrum's Law: 観察可能なら誰かが依存している。すべての公開挙動をコミットメントとして扱う。 |
| "2つのバージョンを維持すればいい" | 複数バージョンはメンテナンスコストを増やしダイヤモンド依存問題を作る。ワンバージョンルールを好む。 |
| "内部APIにはコントラクト不要" | 内部消費者も消費者。コントラクトはカップリングを防ぎ並列作業を可能にする。 |

## レッドフラグ

- 条件に応じて異なる形を返すエンドポイント
- エンドポイント間で一貫しないエラーフォーマット
- 境界ではなく内部コード全体に散らばった検証
- 既存フィールドへの破壊的変更（型変更、削除）
- ページネーションなしのリストエンドポイント
- REST URLの動詞（`/api/createTask`、`/api/getUsers`）
- 検証やサニタイズなしに使われるサードパーティAPIレスポンス

## 検証

APIを設計した後:

- [ ] すべてのエンドポイントに型付き入力・出力スキーマがある
- [ ] エラーレスポンスが単一の一貫したフォーマットに従う
- [ ] 検証はシステム境界でのみ発生
- [ ] リストエンドポイントがページネーションをサポート
- [ ] 新フィールドは追加的でオプショナル（後方互換）
- [ ] 命名はすべてのエンドポイントで一貫した規約に従う
- [ ] APIドキュメントまたは型が実装と共にコミットされている
