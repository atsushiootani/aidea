---
title: Aidea Specs
description: Aidea のプロダクト仕様 (設計ストック) インデックス。コードベースと 1:1 対応するストック情報のみを扱う
derived_from:
  - docs/LAYOUT.md
syncs_with: []
impacts:
  - docs/specs/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-06
---

# Aidea Specs

Aidea の**プロダクト仕様 (設計ストック)**。コードベースと 1:1 対応する現時点の設計を記述する。
**ストック情報のみ**。MVP スコープ・スケジュール・アイデアなどの**フロー情報は含めない** (GitHub Issues / Milestones で管理)。

## ファイル一覧

| ファイル | 変化頻度 | 内容 |
|---|---|---|
| [architecture.md](./architecture.md) | **中** | 技術スタック / プロジェクト構造 / レイヤー・主要コンポーネント |
| [aspects/](./aspects/) | **中** | 横断的関心事 (キー操作一覧 / 永続化仕様 / View 階層) |
| [tools/](./tools/) | **中** | 各ツールの実装仕様 (Terminal / Git / Kit / Preview / Obsidian など) |
| [frontchannels/](./frontchannels/) | **中** | 会話 UI (Scene / 発話フロー) |
| [companions/](./companions/) | **中** | コンパニオン (9 体のアイコン) とレコメンドモード |
| [backchannels/](./backchannels/) | **中** | 裏側処理 (読み上げ / VOICEVOX 連携など) |
| [sessions/](./sessions/) | **中** | Session 概念の詳細 (概念モデル・アクティブ切替・UI ルール) |
| [widgets/](./widgets/) | **中** | ヘッダ常駐型の小さな補助機能 (ポモドーロ / TODO 等) |
| [skills/](./skills/) | **低中** | Claude Code スキルの仕様 (concier スケジュールリマインド等) |
| [window/](./window/) | **中低** | Window 全体の振る舞い (ダイアログ・グローバルショートカット) |
| [glossary.md](./glossary.md) | **低中** | 用語集 |

コーディング規約は [../conventions/](../conventions/) に分離した。

## 読む順番 (初見)

1. [../foundation/vision.md](../foundation/vision.md) — 動機・誰のため・成功基準
2. [sessions/ui-rules.md#概念モデル](./sessions/ui-rules.md#概念モデル) — Window / Pane / Tab / Session / Tool の 5 概念
3. [glossary.md](./glossary.md) — 用語の確認
4. [architecture.md](./architecture.md) — コード構造の把握
5. [../conventions/rules.md](../conventions/rules.md) — Always / Never の具体ルール
6. [../conventions/coding-style.md](../conventions/coding-style.md) / [../conventions/testing.md](../conventions/testing.md) — 手を動かす前に

## 関連

- [../foundation/vision.md](../foundation/vision.md) — なぜこれを作るのか (動機と原則)
- [../decisions/](../decisions/README.md) — 設計判断の記録 (ADR)
- [../plans/](../plans/) — 実装計画書 (git 管理外)

---

## ヘルスチェック (PR 時に実施)

specs は「コードベースと 1:1 対応するストック情報」が原則。放っておくと陳腐化・重複・抜け漏れが溜まりやすい。PR レビューのタイミングで以下を走らせる。Claude Code で `/aidea.docs-healthcheck` コマンド (specs / decisions 両方まとめて実行) または「specs のヘルスチェックして」と自然言語で実行可能。

### チェック項目

1. **specs ドキュメント同士の矛盾**
   - 2 つ以上のファイルが同じ事実について**異なる記述**をしていないか
   - 例: `architecture.md` と `sessions/ui-rules.md` でコンポーネント名や責務が食い違う

2. **decisions (ADR) との矛盾**
   - specs の記述が **[../decisions/](../decisions/) で採用された方針と反していないか**
   - 例: ADR 0002「コードエディタ機能を持たない」に反してエディタ機能の仕様が書かれている
   - ADR が「暫定」「提案」状態の場合は指摘レベルを下げる

3. **コードベースとの矛盾** (stale specs)
   - 実装が変わったのに specs が古いままになっていないか
   - 例: `Sessions/Skills/` が削除されたのに specs に残っている、クラス名や API が実態と違う

4. **コードにあるのに specs に書かれていない機能・概念**
   - `Aidea/Aidea/` 配下に存在する **公開的な機能や概念**が specs のどこにも登場しない場合をフラグ
   - **対象外**: 1 つのファイルにしか登場しない変数・private メソッド・ローカル実装詳細 / テストコード / ユーティリティ的な小さなヘルパー

5. **永続化データの抜け**
   - コードベースで `UserDefaults` / Keychain / `.aidea/*.json` 等に読み書きしているが [persistence.md](./aspects/persistence.md) に記載がないものをフラグ

6. **aspects（横断的関心事）との整合性**
   - 機能群の変更が [aspects/](./aspects/README.md) に反映されていないものをフラグ（詳細は [aspects/README.md](./aspects/README.md) の更新ルールを参照）

### フラグへの対応

| フラグ | 基本方針 | 追加アクション |
|---|---|---|
| **specs 同士の矛盾** | ユーザに問い合わせ | どちらが正しいか確認し、誤った方を修正 or 統合 |
| **decisions との矛盾** | 基本は ADR が優先 (ユーザ確認) | specs 側を修正。ADR の方を見直すなら ADR 0012→0013 の要領で「進化予定」注記を追加 |
| **コードベースとの矛盾** | **現コードを正とする** (ユーザ確認) | 古い specs を最新実装に合わせて書き換える |
| **未記載の機能・概念** | ユーザに問い合わせ | 仕様を書く ([該当サブディレクトリ](./) に追加) か、無視してよいかを選択 |
| **永続化データの抜け** | ユーザに問い合わせ | [persistence.md](./aspects/persistence.md) に追記するか、テンポラリなら無視かを選択 |
| **aspects との不整合** | **specs 側を正とする** | 機能群の変更を [aspects/](./aspects/) に反映する |

### 運用

- **PR のたび**に Claude Code で `/aidea.docs-healthcheck` を実行 (decisions と同時にチェックされる)
- フラグが立ったら PR 内で解消する (別 PR に持ち越さない)
- 問題なしなら特に何もしない (サイレント pass)
