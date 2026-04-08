---
name: frontend-ui-engineering
description: Builds production-quality UIs. Use when building or modifying user-facing interfaces. Use when creating components, implementing layouts, managing state, or when the output needs to look and feel production-quality rather than AI-generated.
---

# フロントエンドUIエンジニアリング

## 概要

アクセシブルで高性能で視覚的に磨かれた、プロダクション品質のユーザーインターフェイスを作る。ゴールは、トップ企業のデザイン意識のあるエンジニアが作ったように見えるUI — AIが生成したように見えないこと。これは実際のデザインシステム準拠、適切なアクセシビリティ、思慮深いインタラクションパターン、そして汎用的な「AI美学」がないことを意味する。

## 使うタイミング

- 新しいUIコンポーネントやページを作るとき
- 既存のユーザー向けインターフェイスを変更するとき
- レスポンシブレイアウトを実装するとき
- インタラクティビティや状態管理を追加するとき
- 視覚的またはUX問題を修正するとき

## コンポーネントアーキテクチャ

### ファイル構造

コンポーネントに関連するすべてをコロケート:

```
src/components/
  TaskList/
    TaskList.tsx          # コンポーネント実装
    TaskList.test.tsx     # テスト
    TaskList.stories.tsx  # Storybook ストーリー（使う場合）
    use-task-list.ts      # カスタムフック（状態が複雑な場合）
    types.ts              # コンポーネント固有の型（必要な場合）
```

### コンポーネントパターン

**設定よりコンポジション:**

```tsx
// 良: コンポジション可能
<Card>
  <CardHeader>
    <CardTitle>Tasks</CardTitle>
  </CardHeader>
  <CardBody>
    <TaskList tasks={tasks} />
  </CardBody>
</Card>

// 避ける: 過剰設定
<Card
  title="Tasks"
  headerVariant="large"
  bodyPadding="md"
  content={<TaskList tasks={tasks} />}
/>
```

**コンポーネントはフォーカスされた状態に:**

```tsx
// 良: 一つのことだけ行う
export function TaskItem({ task, onToggle, onDelete }: TaskItemProps) {
  return (
    <li className="flex items-center gap-3 p-3">
      <Checkbox checked={task.done} onChange={() => onToggle(task.id)} />
      <span className={task.done ? 'line-through text-muted' : ''}>{task.title}</span>
      <Button variant="ghost" size="sm" onClick={() => onDelete(task.id)}>
        <TrashIcon />
      </Button>
    </li>
  );
}
```

**データフェッチとプレゼンテーションを分離:**

```tsx
// コンテナ: データを扱う
export function TaskListContainer() {
  const { tasks, isLoading, error } = useTasks();

  if (isLoading) return <TaskListSkeleton />;
  if (error) return <ErrorState message="Failed to load tasks" retry={refetch} />;
  if (tasks.length === 0) return <EmptyState message="No tasks yet" />;

  return <TaskList tasks={tasks} />;
}

// プレゼンテーション: レンダリングを扱う
export function TaskList({ tasks }: { tasks: Task[] }) {
  return (
    <ul role="list" className="divide-y">
      {tasks.map(task => <TaskItem key={task.id} task={task} />)}
    </ul>
  );
}
```

## 状態管理

**動く最もシンプルなアプローチを選ぶ:**

```
ローカル状態 (useState)            → コンポーネント固有の UI 状態
リフトアップした状態               → 2〜3 個の兄弟コンポーネント間で共有
Context                            → テーマ、認証、ロケール（読み多め、書き稀）
URL 状態 (searchParams)            → フィルタ、ページネーション、共有可能な UI 状態
サーバー状態 (React Query, SWR)    → キャッシュ付きリモートデータ
グローバルストア (Zustand, Redux)  → アプリ全体で共有する複雑なクライアント状態
```

**3層より深いプロップドリルは避ける。** 使わないコンポーネントを通してプロップを渡しているなら、コンテキストを導入するかコンポーネントツリーを再構成する。

## デザインシステム準拠

### AI美学を避ける

AI生成UIには認識可能なパターンがある。すべて避けること:

| AIデフォルト | なぜ問題か | プロダクション品質 |
|---|---|---|
| すべて紫/インディゴ | モデルは視覚的に「安全」なパレットをデフォルトにし、すべてのアプリが同じに見える | プロジェクトの実際のカラーパレットを使う |
| 過剰なグラデーション | グラデーションは視覚ノイズを加え、大抵のデザインシステムと衝突 | フラットまたはデザインシステムに合うさりげないグラデーション |
| すべて丸い（rounded-2xl） | 最大丸めは「フレンドリー」を示すが実際のデザインの角丸階層を無視 | デザインシステムから一貫したborder-radius |
| 汎用ヒーローセクション | 実際のコンテンツやユーザーニーズとつながりのないテンプレート駆動レイアウト | コンテンツファーストレイアウト |
| Lorem ipsumスタイルのコピー | プレースホルダーテキストは実コンテンツが明らかにするレイアウト問題（長さ、折り返し、オーバーフロー）を隠す | 現実的なプレースホルダーコンテンツ |
| すべてに過大なパディング | 等しい寛大なパディングは視覚階層を破壊し画面スペースを浪費 | 一貫したスペーシングスケール |
| ストックカードグリッド | 均一グリッドは情報優先度とスキャンパターンを無視するレイアウトショートカット | 目的駆動レイアウト |
| シャドウ重いデザイン | レイヤードシャドウはコンテンツと競合する深さを加え、低性能デバイスでレンダリングを遅くする | デザインシステムが指定しない限りさりげないかシャドウなし |

### スペーシングとレイアウト

一貫したスペーシングスケールを使う。値を発明しない:

```css
/* スケールを使う: 0.25rem 刻み（プロジェクトで使うものに合わせる） */
/* 良 */  padding: 1rem;      /* 16px */
/* 良 */  gap: 0.75rem;       /* 12px */
/* 悪 */  padding: 13px;      /* スケールから外れている */
/* 悪 */  margin-top: 2.3rem; /* スケールから外れている */
```

### タイポグラフィ

タイプ階層を尊重:

```
h1 → ページタイトル（ページに 1 つ）
h2 → セクションタイトル
h3 → サブセクションタイトル
body → 既定のテキスト
small → 補助・ヘルパーテキスト
```

見出しレベルをスキップしない。見出しスタイルを見出し以外のコンテンツに使わない。

### カラー

- セマンティックカラートークン（`text-primary`、`bg-surface`、`border-default`）を使う — 生のhex値ではなく
- 十分なコントラスト（通常テキストで4.5:1、大きなテキストで3:1）を確保
- 情報を伝えるのに色だけに頼らない（アイコン、テキスト、パターンも使う）

## アクセシビリティ（WCAG 2.1 AA）

すべてのコンポーネントはこれらの基準を満たす必要がある:

### キーボードナビゲーション

```tsx
// すべてのインタラクティブ要素はキーボードでアクセス可能であること
<button onClick={handleClick}>Click me</button>        // ✓ 既定でフォーカス可能
<div onClick={handleClick}>Click me</div>               // ✗ フォーカス不可
<div role="button" tabIndex={0} onClick={handleClick}    // ✓ ただし <button> を推奨
     onKeyDown={e => e.key === 'Enter' && handleClick()}>
  Click me
</div>
```

### ARIAラベル

```tsx
// 可視テキストのないインタラクティブ要素にはラベルを付ける
<button aria-label="Close dialog"><XIcon /></button>

// フォーム入力にラベルを付ける
<label htmlFor="email">Email</label>
<input id="email" type="email" />

// 可視ラベルがない場合は aria-label を使う
<input aria-label="Search tasks" type="search" />
```

### フォーカス管理

```tsx
// コンテンツが変わったらフォーカスを移動する
function Dialog({ isOpen, onClose }: DialogProps) {
  const closeRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (isOpen) closeRef.current?.focus();
  }, [isOpen]);

  // 開いている間はダイアログ内にフォーカスをトラップ
  return (
    <dialog open={isOpen}>
      <button ref={closeRef} onClick={onClose}>Close</button>
      {/* dialog content */}
    </dialog>
  );
}
```

### 意味のあるエンプティ/エラー状態

```tsx
// 空白の画面を表示しない
function TaskList({ tasks }: { tasks: Task[] }) {
  if (tasks.length === 0) {
    return (
      <div role="status" className="text-center py-12">
        <TasksEmptyIcon className="mx-auto h-12 w-12 text-muted" />
        <h3 className="mt-2 text-sm font-medium">No tasks</h3>
        <p className="mt-1 text-sm text-muted">Get started by creating a new task.</p>
        <Button className="mt-4" onClick={onCreateTask}>Create Task</Button>
      </div>
    );
  }

  return <ul role="list">...</ul>;
}
```

## レスポンシブデザイン

モバイルファーストで設計し、拡張:

```tsx
// Tailwind: モバイルファーストでレスポンシブ
<div className="
  grid grid-cols-1      /* モバイル: 1 カラム */
  sm:grid-cols-2        /* Small: 2 カラム */
  lg:grid-cols-3        /* Large: 3 カラム */
  gap-4
">
```

これらのブレークポイントでテスト: 320px、768px、1024px、1440px。

## ローディングとトランジション

```tsx
// スケルトンローディング（コンテンツにはスピナーを使わない）
function TaskListSkeleton() {
  return (
    <div className="space-y-3" aria-busy="true" aria-label="Loading tasks">
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="h-12 bg-muted animate-pulse rounded" />
      ))}
    </div>
  );
}

// 体感速度のための楽観的更新
function useToggleTask() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: toggleTask,
    onMutate: async (taskId) => {
      await queryClient.cancelQueries({ queryKey: ['tasks'] });
      const previous = queryClient.getQueryData(['tasks']);

      queryClient.setQueryData(['tasks'], (old: Task[]) =>
        old.map(t => t.id === taskId ? { ...t, done: !t.done } : t)
      );

      return { previous };
    },
    onError: (_err, _taskId, context) => {
      queryClient.setQueryData(['tasks'], context?.previous);
    },
  });
}
```

## 参照

詳細なアクセシビリティ要件とテストツールについては `references/accessibility-checklist.md` 参照。

## よくある言い訳

| 言い訳 | 現実 |
|---|---|
| "アクセシビリティはあったらいいもの" | 多くの司法管轄で法的要件であり、エンジニアリング品質基準。 |
| "後でレスポンシブにする" | レスポンシブデザインの後付けは最初から作るより3倍難しい。 |
| "デザインが最終版ではないのでスタイリングはスキップ" | デザインシステムのデフォルトを使う。スタイルのないUIはレビュアーに壊れた第一印象を作る。 |
| "これは単なるプロトタイプ" | プロトタイプはプロダクションコードになる。基盤を正しく作る。 |
| "AI美学は今は問題ない" | 低品質を示す。プロジェクトの実際のデザインシステムを最初から使う。 |

## レッドフラグ

- 200行以上のコンポーネント（分割する）
- インラインスタイルや任意のピクセル値
- エラー状態、ローディング状態、エンプティ状態の欠如
- キーボードナビゲーションテストなし
- 状態の唯一のインジケータとしての色（テキストやアイコンなしの赤/緑）
- 汎用的な「AIルック」（紫グラデーション、過大なカード、ストックレイアウト）

## 検証

UIを作った後:

- [ ] コンポーネントがコンソールエラーなしにレンダリングする
- [ ] すべてのインタラクティブ要素がキーボードアクセシブル（ページをTabで通過）
- [ ] スクリーンリーダーがページのコンテンツと構造を伝えられる
- [ ] レスポンシブ: 320px、768px、1024px、1440pxで動作
- [ ] ローディング、エラー、エンプティ状態すべて扱っている
- [ ] プロジェクトのデザインシステム（スペーシング、カラー、タイポグラフィ）に従っている
- [ ] dev toolsまたはaxe-coreでアクセシビリティ警告なし
