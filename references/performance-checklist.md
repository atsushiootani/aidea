# パフォーマンスチェックリスト

Web アプリケーションのパフォーマンスに関するクイックリファレンス。`performance-optimization` スキルと併用してください。

## 目次

- [Core Web Vitals 目標値](#core-web-vitals-目標値)
- [フロントエンドチェックリスト](#フロントエンドチェックリスト)
- [バックエンドチェックリスト](#バックエンドチェックリスト)
- [計測コマンド](#計測コマンド)
- [よくあるアンチパターン](#よくあるアンチパターン)

## Core Web Vitals 目標値

| 指標 | Good | Needs Work | Poor |
|--------|------|------------|------|
| LCP (Largest Contentful Paint) | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| INP (Interaction to Next Paint) | ≤ 200ms | ≤ 500ms | > 500ms |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

## フロントエンドチェックリスト

### 画像
- [ ] モダンフォーマット（WebP、AVIF）を使用
- [ ] レスポンシブサイズ（`srcset` と `sizes`）
- [ ] 明示的な `width` と `height` 属性（CLS 防止）
- [ ] スクロール下の画像に `loading="lazy"`
- [ ] ヒーロー/LCP 画像に `fetchpriority="high"`、lazy 読込なし

### JavaScript
- [ ] バンドルサイズは gzip 後 200KB 未満（初回ロード）
- [ ] ルートや重機能は動的 `import()` でコード分割
- [ ] ツリーシェイキング有効（本番バンドルにデッドコードなし）
- [ ] `<head>` にブロッキング JS なし（`defer` または `async` を使用）
- [ ] 重い処理は Web Worker にオフロード（該当時）
- [ ] 同じ props で再レンダーする高コストなコンポーネントに `React.memo()`
- [ ] `useMemo()` / `useCallback()` はプロファイルで効果がある箇所のみ

### CSS
- [ ] クリティカル CSS のインライン化またはプリロード
- [ ] 非クリティカルなスタイルでレンダリングをブロックしない
- [ ] 本番で CSS-in-JS のランタイムコストなし（抽出を使用）
- [ ] フォント表示戦略を設定（`font-display: swap` または `optional`）
- [ ] カスタムフォント前にシステムフォントスタックを検討

### ネットワーク
- [ ] 静的アセットは長い `max-age` ＋コンテンツハッシュでキャッシュ
- [ ] API レスポンスは必要に応じてキャッシュ（`Cache-Control`）
- [ ] HTTP/2 または HTTP/3 有効
- [ ] 既知オリジンに `<link rel="preconnect">`
- [ ] 不要なリダイレクトなし

### レンダリング
- [ ] レイアウトスラッシング（強制同期レイアウト）なし
- [ ] アニメーションは `transform` と `opacity`（GPU 加速）
- [ ] 長いリストは仮想化（例: `react-window`）
- [ ] 不要なページ全体の再レンダーなし

## バックエンドチェックリスト

### データベース
- [ ] N+1 クエリパターンなし（eager loading / join 使用）
- [ ] クエリに適切なインデックス
- [ ] リストエンドポイントはページネーション（`SELECT * FROM table` 禁止）
- [ ] コネクションプーリング設定済み
- [ ] スロークエリログ有効

### API
- [ ] レスポンスタイム < 200ms (p95)
- [ ] リクエストハンドラ内に同期的な重い計算なし
- [ ] 個別呼び出しのループではなく一括処理
- [ ] レスポンス圧縮（gzip/brotli）
- [ ] 適切なキャッシュ（インメモリ、Redis、CDN）

### インフラ
- [ ] 静的アセットに CDN
- [ ] サーバーをユーザーの近くに配置（またはエッジデプロイ）
- [ ] 水平スケーリング設定（必要な場合）
- [ ] ロードバランサ用のヘルスチェックエンドポイント

## 計測コマンド

```bash
# Lighthouse CLI
npx lighthouse https://localhost:3000 --output json --output-path ./report.json

# バンドル分析
npx webpack-bundle-analyzer stats.json
# Vite の場合:
npx vite-bundle-visualizer

# バンドルサイズ確認
npx bundlesize

# コード内で Web Vitals
import { onLCP, onINP, onCLS } from 'web-vitals';
onLCP(console.log);
onINP(console.log);
onCLS(console.log);
```

## よくあるアンチパターン

| アンチパターン | 影響 | 修正 |
|---|---|---|
| N+1 クエリ | DB 負荷の線形増加 | join、include、バッチロード |
| 無制限クエリ | メモリ枯渇、タイムアウト | 必ずページネーション、LIMIT |
| インデックス不足 | データ増加で読み取り遅延 | フィルタ/ソート列にインデックス |
| レイアウトスラッシング | ジャンク、フレーム落ち | DOM 読み取りをまとめてから書き込み |
| 未最適化画像 | LCP 遅延、帯域浪費 | WebP、レスポンシブ、lazy 読込 |
| 大きなバンドル | Time to Interactive 遅延 | コード分割、ツリーシェイク、依存監査 |
| メインスレッドブロック | INP 悪化、UI 無反応 | Web Worker、処理遅延 |
| メモリリーク | メモリ増加、クラッシュ | リスナー、interval、ref のクリーンアップ |
