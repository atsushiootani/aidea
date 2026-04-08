# テストパターンリファレンス

スタック全体でよく使われるテストパターンのクイックリファレンス。`test-driven-development` スキルと併用してください。

## 目次

- [テスト構造 (Arrange-Act-Assert)](#テスト構造-arrange-act-assert)
- [テスト命名規則](#テスト命名規則)
- [よくあるアサーション](#よくあるアサーション)
- [モックパターン](#モックパターン)
- [React/コンポーネントテスト](#reactコンポーネントテスト)
- [API / 結合テスト](#api--結合テスト)
- [E2E テスト (Playwright)](#e2e-テスト-playwright)
- [テストアンチパターン](#テストアンチパターン)

## テスト構造 (Arrange-Act-Assert)

```typescript
it('期待される振る舞いを記述', () => {
  // Arrange: テストデータと事前条件を準備
  const input = { title: 'Test Task', priority: 'high' };

  // Act: テスト対象のアクションを実行
  const result = createTask(input);

  // Assert: 結果を検証
  expect(result.title).toBe('Test Task');
  expect(result.priority).toBe('high');
  expect(result.status).toBe('pending');
});
```

## テスト命名規則

```typescript
// パターン: [対象] [期待される振る舞い] [条件]
describe('TaskService.createTask', () => {
  it('creates a task with default pending status', () => {});
  it('throws ValidationError when title is empty', () => {});
  it('trims whitespace from title', () => {});
  it('generates a unique ID for each task', () => {});
});
```

## よくあるアサーション

```typescript
// 等価性
expect(result).toBe(expected);           // 厳密等価 (===)
expect(result).toEqual(expected);        // 深い等価（オブジェクト/配列）
expect(result).toStrictEqual(expected);  // 深い等価 + 型一致

// 真偽
expect(result).toBeTruthy();
expect(result).toBeFalsy();
expect(result).toBeNull();
expect(result).toBeDefined();
expect(result).toBeUndefined();

// 数値
expect(result).toBeGreaterThan(5);
expect(result).toBeLessThanOrEqual(10);
expect(result).toBeCloseTo(0.3, 5);      // 浮動小数点

// 文字列
expect(result).toMatch(/pattern/);
expect(result).toContain('substring');

// 配列 / オブジェクト
expect(array).toContain(item);
expect(array).toHaveLength(3);
expect(object).toHaveProperty('key', 'value');

// エラー
expect(() => fn()).toThrow();
expect(() => fn()).toThrow(ValidationError);
expect(() => fn()).toThrow('specific message');

// 非同期
await expect(asyncFn()).resolves.toBe(value);
await expect(asyncFn()).rejects.toThrow(Error);
```

## モックパターン

### モック関数

```typescript
const mockFn = jest.fn();
mockFn.mockReturnValue(42);
mockFn.mockResolvedValue({ data: 'test' });
mockFn.mockImplementation((x) => x * 2);

expect(mockFn).toHaveBeenCalled();
expect(mockFn).toHaveBeenCalledWith('arg1', 'arg2');
expect(mockFn).toHaveBeenCalledTimes(3);
```

### モジュールのモック

```typescript
// モジュール全体のモック
jest.mock('./database', () => ({
  query: jest.fn().mockResolvedValue([{ id: 1, title: 'Test' }]),
}));

// 特定のエクスポートのみモック
jest.mock('./utils', () => ({
  ...jest.requireActual('./utils'),
  generateId: jest.fn().mockReturnValue('test-id'),
}));
```

### 境界のみモックする

```
モックする対象:                   モックしない対象:
├── データベース呼び出し           ├── 内部ユーティリティ関数
├── HTTP リクエスト                ├── ビジネスロジック
├── ファイルシステム操作           ├── データ変換
├── 外部 API 呼び出し              ├── バリデーション関数
└── 時刻/日付（必要な場合）        └── 純粋関数
```

## React/コンポーネントテスト

```tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';

describe('TaskForm', () => {
  it('submits the form with entered data', async () => {
    const onSubmit = jest.fn();
    render(<TaskForm onSubmit={onSubmit} />);

    // アクセシブルな role/label で要素を見つける（test ID ではなく）
    await screen.findByRole('textbox', { name: /title/i });
    fireEvent.change(screen.getByRole('textbox', { name: /title/i }), {
      target: { value: 'New Task' },
    });
    fireEvent.click(screen.getByRole('button', { name: /create/i }));

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith({ title: 'New Task' });
    });
  });

  it('shows validation error for empty title', async () => {
    render(<TaskForm onSubmit={jest.fn()} />);

    fireEvent.click(screen.getByRole('button', { name: /create/i }));

    expect(await screen.findByText(/title is required/i)).toBeInTheDocument();
  });
});
```

## API / 結合テスト

```typescript
import request from 'supertest';
import { app } from '../src/app';

describe('POST /api/tasks', () => {
  it('creates a task and returns 201', async () => {
    const response = await request(app)
      .post('/api/tasks')
      .send({ title: 'Test Task' })
      .set('Authorization', `Bearer ${testToken}`)
      .expect(201);

    expect(response.body).toMatchObject({
      id: expect.any(String),
      title: 'Test Task',
      status: 'pending',
    });
  });

  it('returns 422 for invalid input', async () => {
    const response = await request(app)
      .post('/api/tasks')
      .send({ title: '' })
      .set('Authorization', `Bearer ${testToken}`)
      .expect(422);

    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('returns 401 without authentication', async () => {
    await request(app)
      .post('/api/tasks')
      .send({ title: 'Test' })
      .expect(401);
  });
});
```

## E2E テスト (Playwright)

```typescript
import { test, expect } from '@playwright/test';

test('user can create and complete a task', async ({ page }) => {
  // ナビゲートして認証
  await page.goto('/');
  await page.fill('[name="email"]', 'test@example.com');
  await page.fill('[name="password"]', 'testpass123');
  await page.click('button:has-text("Log in")');

  // タスクを作成
  await page.click('button:has-text("New Task")');
  await page.fill('[name="title"]', 'Buy groceries');
  await page.click('button:has-text("Create")');

  // タスクが表示されることを確認
  await expect(page.locator('text=Buy groceries')).toBeVisible();

  // タスクを完了
  await page.click('[aria-label="Complete Buy groceries"]');
  await expect(page.locator('text=Buy groceries')).toHaveCSS(
    'text-decoration-line', 'line-through'
  );
});
```

## テストアンチパターン

| アンチパターン | 問題 | より良いアプローチ |
|---|---|---|
| 実装詳細のテスト | リファクタで壊れる | 入出力をテスト |
| すべてをスナップショット | 誰も差分をレビューしない | 具体的な値をアサート |
| 可変状態の共有 | テスト同士が汚染する | テストごとに setup/teardown |
| サードパーティのテスト | 時間の無駄、自分のバグではない | 境界をモック |
| CI 通過のためテストスキップ | 本物のバグを隠す | 修正するか削除する |
| `test.skip` を放置 | デッドコード | 削除か修正 |
| 広すぎるアサーション | リグレッションを捉えられない | 具体的に |
| 非同期エラー未処理 | エラー握りつぶし、偽合格 | 非同期テストは必ず `await` |
