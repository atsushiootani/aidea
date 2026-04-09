# Aidea Specs

Aidea プロジェクトの仕様書群。変化頻度ごとにファイルを分離している。

## ファイル一覧

| ファイル | 変化頻度 | 内容 |
|---|---|---|
| [SPEC.md](./SPEC.md) | **高** | 目的 / スコープ / MVP / 概念モデル / Phase ロードマップ / 改訂履歴 |
| [architecture.md](./architecture.md) | **中** | 技術スタック / プロジェクト構造 / レイヤー・主要コンポーネント |
| [coding-style.md](./coding-style.md) | **低** | Swift 規約 / プロパティラッパ並び順 / コメント方針 / 並行性 |
| [testing.md](./testing.md) | **低** | テスト戦略 / 手動確認チェックリスト |
| [boundaries.md](./boundaries.md) | **中低** | Always / Confirm First / Never |
| [glossary.md](./glossary.md) | **低中** | 用語集 |

## 読む順番 (初見)

1. [SPEC.md](./SPEC.md) — まずは目的と MVP 範囲
2. [glossary.md](./glossary.md) — 用語の確認
3. [architecture.md](./architecture.md) — コード構造の把握
4. [boundaries.md](./boundaries.md) — やって良いこと・ダメなこと
5. [coding-style.md](./coding-style.md) / [testing.md](./testing.md) — 手を動かす前に

## 関連

- [../vision.md](../vision.md) — なぜこれを作るのか (背景)
- [../features.md](../features.md) — 機能の実装メモ
- [../decisions/](../decisions/README.md) — 設計判断の記録 (ADR)
- [../plans/](../plans/) — 実装計画書
