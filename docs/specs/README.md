# Aidea Specs

Aidea の**プロダクト仕様 (設計ストック)**。コードベースと 1:1 対応する現時点の設計を記述する。
**ストック情報のみ**。MVP スコープ・スケジュール・アイデアなどの**フロー情報は含めない** (GitHub Issues / Milestones で管理)。

## ファイル一覧

| ファイル | 変化頻度 | 内容 |
|---|---|---|
| [architecture.md](./architecture.md) | **中** | 技術スタック / プロジェクト構造 / レイヤー・主要コンポーネント |
| [tools/](./tools/) | **中** | 各ツールの実装仕様 (Terminal / Git / Kit / Preview / Obsidian など) |
| [frontchannel/](./frontchannel/) | **中** | 会話 UI (Scene / Recommend / 発話フロー) |
| [backchannels/](./backchannels/) | **中** | 裏側処理 (読み上げ / VOICEVOX 連携など) |
| [session/](./session/) | **中** | Session 概念の詳細 (概念モデル・アクティブ切替など) |
| [boundaries.md](./boundaries.md) | **中低** | Always / Confirm First / Never |
| [glossary.md](./glossary.md) | **低中** | 用語集 |

コーディング規約は [../conventions/](../conventions/) に分離した。

## 読む順番 (初見)

1. [../foundation/vision.md](../foundation/vision.md) — 動機・誰のため・成功基準
2. [session/concept-model.md](./session/concept-model.md) — Window / Pane / Tab / Session / Tool の 5 概念
3. [glossary.md](./glossary.md) — 用語の確認
4. [architecture.md](./architecture.md) — コード構造の把握
5. [boundaries.md](./boundaries.md) — やって良いこと・ダメなこと
6. [../conventions/coding-style.md](../conventions/coding-style.md) / [../conventions/testing.md](../conventions/testing.md) — 手を動かす前に

## 関連

- [../foundation/vision.md](../foundation/vision.md) — なぜこれを作るのか (動機と原則)
- [../decisions/](../decisions/README.md) — 設計判断の記録 (ADR)
- [../plans/](../plans/) — 実装計画書 (git 管理外)
