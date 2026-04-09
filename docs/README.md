# Aidea Documentation

> AI + IDE + Idea — 個人用の Mac ネイティブ AI コーディング環境

## ドキュメント構成

### 仕様書群 ([specs/](./specs/README.md))
変化頻度ごとにファイル分割した仕様書。

| ファイル | 変化頻度 | 内容 |
|---|---|---|
| [specs/SPEC.md](./specs/SPEC.md) | 高 | 目的 / MVP / 概念モデル / Phase ロードマップ |
| [specs/architecture.md](./specs/architecture.md) | 中 | 技術スタック / プロジェクト構造 |
| [specs/coding-style.md](./specs/coding-style.md) | 低 | Swift 規約 / プロパティラッパ並び順 |
| [specs/testing.md](./specs/testing.md) | 低 | テスト戦略 / 手動チェック |
| [specs/boundaries.md](./specs/boundaries.md) | 中低 | Always / Confirm First / Never |
| [specs/glossary.md](./specs/glossary.md) | 低中 | 用語集 |

### 背景・経緯

| ファイル | 内容 |
|---|---|
| [vision.md](./vision.md) | なぜ作るか、原則、成功基準 |
| [features.md](./features.md) | 機能の実装メモ |
| [webview-notes.md](./webview-notes.md) | WKWebView vs Safari vs Chrome の比較 |
| [roadmap.md](./roadmap.md) | 実装スケジュール |

### 判断と計画

| ファイル | 内容 |
|---|---|
| [decisions/](./decisions/README.md) | 設計判断の記録 (ADR) |
| [plans/](./plans/) | 過去・現在の実装計画書 |

## プロジェクト名の由来

**Aidea** = AI + IDE + Idea のトリプルミーニング
- **AI**: AI エージェント連携が中核
- **IDE**: 統合開発「環境」(エディタは含まない)
- **Idea**: アイデアを形にする場所

## 現在の状態

Phase 1 完了。ファイラ・マルチタブ・Session 概念・Preview ダブルクリックが動作する。
詳細は [specs/SPEC.md](./specs/SPEC.md) 参照。
