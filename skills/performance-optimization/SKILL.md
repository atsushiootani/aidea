---
name: performance-optimization
description: Optimizes application performance. Use when performance requirements exist, when you suspect performance regressions, or when Core Web Vitals or load times need improvement. Use when profiling reveals bottlenecks that need fixing.
---

# パフォーマンス最適化

## 概要

最適化する前に計測せよ。計測なしのパフォーマンス作業は推測であり、推測は早過ぎる最適化を招いて重要でない部分に複雑さを加える。先にプロファイル、実際のボトルネックを特定、修正、再計測。計測が重要だと証明したものだけ最適化する。

## 使うとき

- 仕様にパフォーマンス要件がある（ロード時間予算、応答時間SLA）
- ユーザーや監視が遅い挙動を報告
- Core Web Vitalsスコアがしきい値を下回る
- 変更がリグレッションを導入した疑い
- 大規模データセットや高トラフィックを扱う機能を構築

**使わないとき:** 問題の証拠がないのに最適化しない。早過ぎる最適化は得られるパフォーマンスより複雑さのコストが高い。

## Core Web Vitals 目標

| 指標 | 良好 | 改善が必要 | 不良 |
|--------|------|-------------------|------|
| **LCP** (Largest Contentful Paint) | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| **INP** (Interaction to Next Paint) | ≤ 200ms | ≤ 500ms | > 500ms |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

## 最適化ワークフロー

```
1. 計測    → 実データでベースライン確立
2. 特定    → 実際のボトルネック発見（想定ではなく）
3. 修正    → 特定のボトルネックに対処
4. 検証    → 再計測、改善を確認
5. ガード  → リグレッション防止の監視やテスト追加
```

### ステップ1: 計測

**フロントエンド:**
```bash
# Chrome DevToolsのLighthouse（またはCI）
# Chrome DevTools → Performanceタブ → Record
# Chrome DevTools MCP → Performance trace

# コード内のWeb Vitalsライブラリ
import { onLCP, onINP, onCLS } from 'web-vitals';

onLCP(console.log);
onINP(console.log);
onCLS(console.log);
```

**バックエンド:**
```bash
# 応答時間ログ
# Application Performance Monitoring (APM)
# タイミング付きDBクエリログ

# 簡単なタイミング
console.time('db-query');
const result = await db.query(...);
console.timeEnd('db-query');
```

### 計測を始める場所

症状で先に計測するものを決める:

```
何が遅い?
├── 初回ページロード
│   ├── 大きなバンドル? --> バンドルサイズ計測、コード分割確認
│   ├── サーバー応答が遅い? --> TTFB計測、API/DBチェック
│   └── レンダーブロックリソース? --> ネットワークウォーターフォールでCSS/JSブロックをチェック
├── インタラクションが重い
│   ├── クリックでUI固まる? --> メインスレッドプロファイル、ロングタスク（>50ms）を探す
│   ├── フォーム入力ラグ? --> 再レンダー、controlled componentオーバーヘッドをチェック
│   └── アニメーションのジャンク? --> レイアウトスラッシング、強制リフローをチェック
├── ナビゲーション後のページ
│   ├── データロード? --> API応答時間計測、ウォーターフォールチェック
│   └── クライアントレンダー? --> コンポーネントレンダー時間プロファイル、N+1フェッチチェック
└── バックエンド / API
    ├── 単一エンドポイントが遅い? --> DBクエリプロファイル、インデックス確認
    ├── 全エンドポイントが遅い? --> 接続プール、メモリ、CPUチェック
    └── 断続的な遅さ? --> ロック競合、GC停止、外部依存チェック
```

### ステップ2: ボトルネックの特定

カテゴリ別の一般的なボトルネック:

**フロントエンド:**

| 症状 | 可能性の高い原因 | 調査 |
|---------|-------------|---------------|
| LCP遅い | 大きな画像、レンダーブロックリソース、遅いサーバー | ネットワークウォーターフォール、画像サイズ |
| 高CLS | 寸法なし画像、遅延コンテンツ、フォントシフト | レイアウトシフト属性 |
| INP悪い | メインスレッド上の重いJS、大きなDOM更新 | Performance traceでロングタスク |
| 初期ロード遅い | 大きなバンドル、多数のリクエスト | バンドルサイズ、コード分割 |

**バックエンド:**

| 症状 | 可能性の高い原因 | 調査 |
|---------|-------------|---------------|
| API応答遅い | N+1クエリ、インデックス欠如、未最適化クエリ | DBクエリログ |
| メモリ増加 | 参照リーク、無制限キャッシュ、大きなペイロード | ヒープスナップショット解析 |
| CPUスパイク | 同期重計算、正規表現バックトラック | CPUプロファイリング |
| 高レイテンシ | キャッシュ欠如、冗長計算、ネットワークホップ | スタック全体のリクエストトレース |

### ステップ3: 一般的なアンチパターンの修正

#### N+1クエリ（バックエンド）

```typescript
// 悪: N+1 ――タスクごとに所有者を1クエリ
const tasks = await db.tasks.findMany();
for (const task of tasks) {
  task.owner = await db.users.findUnique({ where: { id: task.ownerId } });
}

// 良: join/includeで単一クエリ
const tasks = await db.tasks.findMany({
  include: { owner: true },
});
```

#### 無制限データフェッチ

```typescript
// 悪: 全レコードをフェッチ
const allTasks = await db.tasks.findMany();

// 良: 上限付きページネーション
const tasks = await db.tasks.findMany({
  take: 20,
  skip: (page - 1) * 20,
  orderBy: { createdAt: 'desc' },
});
```

#### 画像最適化の欠如（フロントエンド）

```html
<!-- 悪: 寸法なし、遅延ロードなし、レスポンシブサイズなし -->
<img src="/hero.jpg" />

<!-- 良: レスポンシブ、遅延ロード、適切サイズ -->
<img
  src="/hero.jpg"
  srcset="/hero-400.webp 400w, /hero-800.webp 800w, /hero-1200.webp 1200w"
  sizes="(max-width: 768px) 100vw, 50vw"
  width="1200"
  height="600"
  loading="lazy"
  alt="Hero image description"
/>
```

#### 不要な再レンダリング（React）

```tsx
// 悪: 毎回新しいオブジェクトを作成、子が再レンダー
function TaskList() {
  return <TaskFilters options={{ sortBy: 'date', order: 'desc' }} />;
}

// 良: 安定参照
const DEFAULT_OPTIONS = { sortBy: 'date', order: 'desc' } as const;
function TaskList() {
  return <TaskFilters options={DEFAULT_OPTIONS} />;
}

// 高コストなコンポーネントにReact.memo
const TaskItem = React.memo(function TaskItem({ task }: Props) {
  return <div>{/* expensive render */}</div>;
});

// 高コストな計算にuseMemo
function TaskStats({ tasks }: Props) {
  const stats = useMemo(() => calculateStats(tasks), [tasks]);
  return <div>{stats.completed} / {stats.total}</div>;
}
```

#### 大きなバンドルサイズ

```typescript
// 悪: ライブラリ全体をimport
import { format } from 'date-fns';

// 良: ツリーシェイカブルなimport（ライブラリが対応している場合）
import { format } from 'date-fns/format';

// 良: 重く希少な機能に動的import
const ChartLibrary = lazy(() => import('./ChartLibrary'));
```

#### キャッシュ欠如（バックエンド）

```typescript
// 頻繁に読まれ稀に変わるデータをキャッシュ
const CACHE_TTL = 5 * 60 * 1000; // 5分
let cachedConfig: AppConfig | null = null;
let cacheExpiry = 0;

async function getAppConfig(): Promise<AppConfig> {
  if (cachedConfig && Date.now() < cacheExpiry) {
    return cachedConfig;
  }
  cachedConfig = await db.config.findFirst();
  cacheExpiry = Date.now() + CACHE_TTL;
  return cachedConfig;
}

// 静的アセット用のHTTPキャッシュヘッダー
app.use('/static', express.static('public', {
  maxAge: '1y',           // 1年キャッシュ
  immutable: true,        // 再検証しない（ファイル名にコンテンツハッシュを使う）
}));

// APIレスポンスのCache-Control
res.set('Cache-Control', 'public, max-age=300'); // 5分
```

## パフォーマンス予算

予算を設定し強制する:

```
JavaScriptバンドル: < 200KB gzipped（初期ロード）
CSS: < 50KB gzipped
画像: < 200KB / 画像（ファーストビュー）
フォント: 合計 < 100KB
API応答時間: < 200ms (p95)
Time to Interactive: 4Gで < 3.5s
Lighthouse Performanceスコア: ≥ 90
```

**CIで強制:**
```bash
# バンドルサイズチェック
npx bundlesize --config bundlesize.config.json

# Lighthouse CI
npx lhci autorun
```

## 関連

詳細なパフォーマンスチェックリスト、最適化コマンド、アンチパターン参照は `references/performance-checklist.md` を参照。


## よくある言い訳

| 言い訳 | 現実 |
|---|---|
| 「後で最適化する」 | パフォーマンス負債は複合する。明らかなアンチパターンは今直し、マイクロ最適化は延期する。 |
| 「自分のマシンでは速い」 | あなたのマシンはユーザーのマシンではない。代表的ハードウェアとネットワークでプロファイル。 |
| 「この最適化は明らか」 | 計測していないならわからない。先にプロファイル。 |
| 「ユーザーは100msに気づかない」 | 研究では100msの遅延がコンバージョン率に影響する。思っているより気づく。 |
| 「フレームワークがパフォーマンスを処理する」 | フレームワークは一部問題を防ぐがN+1や過大バンドルは直せない。 |

## レッドフラグ

- 正当化するプロファイルデータなしの最適化
- データフェッチにN+1クエリパターン
- ページネーションなしのリストエンドポイント
- 寸法・遅延ロード・レスポンシブサイズのない画像
- レビューなしで増えるバンドルサイズ
- 本番にパフォーマンス監視なし
- `React.memo` と `useMemo` を至る所で使う（過剰使用は不足使用と同じく悪い）

## 検証

パフォーマンス関連変更後:

- [ ] 変更前後の計測が存在（具体数値）
- [ ] 特定のボトルネックが特定され対処されている
- [ ] Core Web Vitals が「良好」しきい値内
- [ ] バンドルサイズが大きく増加していない
- [ ] 新しいデータフェッチコードにN+1クエリなし
- [ ] パフォーマンス予算がCIで通る（設定済みの場合)
- [ ] 既存テストが通る（最適化が挙動を壊していない）
