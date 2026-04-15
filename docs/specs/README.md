# Aidea Specs

Aidea プロジェクトの仕様書群。変化頻度ごとにファイルを分離している。

## ファイル一覧

| ファイル | 変化頻度 | 内容 |
|---|---|---|
| [SPEC.md](./SPEC.md) | **高** | 目的 / スコープ / MVP / 概念モデル / Phase ロードマップ / 改訂履歴 |
| [architecture.md](./architecture.md) | **中** | 技術スタック / プロジェクト構造 / レイヤー・主要コンポーネント |
| [tools/](./tools/) | **中** | 各ツールの実装仕様 (Terminal / Git / Kit / Preview / Obsidian など) |
| [frontchannel/](./frontchannel/) | **中** | 会話 UI (Scene / Recommend / 発話フロー) |
| [backchannels/](./backchannels/) | **中** | 裏側処理 (読み上げ / VOICEVOX 連携など) |
| [boundaries.md](./boundaries.md) | **中低** | Always / Confirm First / Never |
| [glossary.md](./glossary.md) | **低中** | 用語集 |

コーディング規約は [../conventions/](../conventions/) に分離した。

## 読む順番 (初見)

1. [SPEC.md](./SPEC.md) — まずは目的と MVP 範囲
2. [glossary.md](./glossary.md) — 用語の確認
3. [architecture.md](./architecture.md) — コード構造の把握
4. [boundaries.md](./boundaries.md) — やって良いこと・ダメなこと
5. [../conventions/coding-style.md](../conventions/coding-style.md) / [../conventions/testing.md](../conventions/testing.md) — 手を動かす前に

## 関連

- [../foundation/vision.md](../foundation/vision.md) — なぜこれを作るのか (背景)
- [../decisions/](../decisions/README.md) — 設計判断の記録 (ADR)
- [../plans/](../plans/) — 実装計画書 (git 管理外)
