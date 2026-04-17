---
description: Run the pre-launch checklist and prepare for production deployment
---

agent-skills:shipping-and-launch スキルを呼び出します。

完全なローンチ前チェックリストを実行します。

1. **コード品質** — テスト通過、ビルドクリーン、Lint クリーン、TODO なし、console.log なし
2. **セキュリティ** — npm audit クリーン、コード内にシークレットなし、認証配備済み、ヘッダ設定済み
3. **パフォーマンス** — Core Web Vitals 良好、N+1 なし、画像最適化、バンドルサイズ適切
4. **アクセシビリティ** — キーボード操作可能、スクリーンリーダー対応、コントラスト十分
5. **インフラ** — 環境変数設定済み、マイグレーション準備完了、監視設定済み
6. **ドキュメント** — README 最新、ADR 記述済み、CHANGELOG 更新済み

失敗したチェック項目を報告し、デプロイ前に解決できるよう支援します。
実施前にロールバック計画を定義します。
