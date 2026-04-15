# docs ディレクトリ構成とファイル配置ルール

新しいドキュメントを追加する際に「どこに、どんな名前で置くか」で迷わないための単一参照先。
変更が生じたらこのファイルも必ず更新すること。

## ツリー構造 (全体像)

```
docs/
├── LAYOUT.md          # 本ファイル。docs配下の配置ルールと命名規約
├── README.md          # docs 全体のインデックス
├── vision.md          # なぜ作るか・原則・成功基準
│
├── agent-skills/      # agent-skills の入門・スキル構造解説ドキュメント置き場
│   ├── getting-started.md
│   └── skill-anatomy.md
│
├── decisions/         # 設計判断を残す ADR (Architecture Decision Records) の保管場所
│   ├── README.md      # ADR 一覧・追加手順
│   └── NNNN-kebab-title.md
│
├── plans/             # タイムスタンプ付きの実装計画書アーカイブ (git 管理外)
│   └── plan_YYYYMMDDHHmmss.md
│
└── specs/             # Aidea の仕様書本体 (SSOT) を構成する設計資料群
    ├── README.md      # specs 内のインデックス・読む順
    ├── SPEC.md        # 目的 / MVP / 概念モデル / Phase ロードマップ
    ├── architecture.md
    ├── boundaries.md
    ├── coding-style.md
    ├── features.md    # 機能の実装メモ
    ├── glossary.md
    ├── principles.md
    ├── roadmap.md     # マイルストーン単位の実装スケジュール
    ├── testing.md
    ├── backchannels/  # 裏側処理 (読み上げ・VOICEVOX 連携など) の仕様
    ├── diagrams/      # アーキテクチャ図などの draw.io / SVG 図表素材
    ├── frontchannel/  # 会話 UI (Scene / Recommend モード等) の仕様
    └── tools/         # claude / git / filer / terminal など各ツール連携の仕様
```

## 配置ルール

新規ドキュメントを追加するときは、用途に該当する節を読んでから書く。
どの節にも当てはまらない用途が出てきたら、先に本ファイルを更新して置き場を定義する。

### 共通ルール

- 拡張子は `.md` (図表のみ `.drawio` / `.svg`)
- ファイル名・ディレクトリ名は全小文字の kebab-case (例外: ルート直下のメタ文書 `README.md` / `LAYOUT.md`)
- 日本語ファイル名は使わない (リンク切れ・ツール非対応回避)
- 1 トピック 1 ファイル。肥大化したらサブディレクトリを切って分割する
- 新しいサブディレクトリを作ったら本ファイルのツリーと配置ルールを同時に更新する

### `docs/` 直下 — 背景・経緯・メタ文書

- **用途**: プロジェクト全体に関わる背景・原則・案内などのトップレベル文書 (`vision.md` など) と、メタ文書 (`README.md` / `LAYOUT.md`)
- **命名**: メタ文書は英大文字 `.md` (`README.md` `LAYOUT.md`)、それ以外は kebab-case 全小文字 (`vision.md`)
- **判断基準**: 下位カテゴリ (decisions / plans / specs / agent-skills) に収まらない全体的トピックのみここに置く

### `docs/decisions/` — 設計判断 (ADR)

- **用途**: 「なぜ A でなく B を選んだか」「後からひっくり返すと影響が大きい決定」を1件1ファイルで記録。既存 ADR の更新で済む場合は新規作成しない
- **命名**: `NNNN-kebab-title.md` (4桁連番)
- **例**: `0013-session-as-first-class-object.md`

### `docs/plans/` — 実装計画 (git 管理外)

- **用途**: ある時点の実装計画スナップショット。セッション固有の作業メモで、陳腐化しやすいため **`.gitignore` で git 管理から外している**
- **命名**: `plan_YYYYMMDDHHmmss.md`
- **例**: `plan_20260414130000.md`
- **永続化**: 計画から出た重要な設計判断は `docs/decisions/` に ADR として昇格させる (plans 単独では残さない)

### `docs/specs/` — 仕様 (あるべき姿)

- **用途**: Aidea の仕様書本体 (SSOT)。性格ごとにサブディレクトリで仕分ける
  - トップレベル概念: `specs/` 直下 (`SPEC.md` / `architecture.md` / `coding-style.md` など)
  - 裏側処理 (読み上げ・音声・非同期処理): `specs/backchannels/`
  - 会話 UI (Scene / Recommend / 発話フロー): `specs/frontchannel/`
  - ツール連携 (claude / git / filer / terminal 等): `specs/tools/`
  - 図表素材: `specs/diagrams/`
- **命名**: kebab-case 全小文字 (`coding-style.md` `recommend-mode.md`)。図表は `<topic>.drawio` と必要に応じて `.svg` を併置 (`simple.drawio` / `simple.drawio.svg`)

### `docs/agent-skills/` — agent-skills 関連の参照資料

- **用途**: プロジェクトルートの `skills/` に配置した agent-skills の入門・解説資料
- **命名**: kebab-case 全小文字 (`getting-started.md` `skill-anatomy.md`)

## インデックス更新の義務

**ファイルを追加・削除・リネームしたら、以下の該当 README を必ず同じコミットで更新する**。
放置するとインデックスが実体と乖離する。

| 対象 | 更新する README | 更新内容 |
|---|---|---|
| 本ファイルのツリーに出てくるディレクトリ/代表ファイルを変更 | `docs/LAYOUT.md` (本ファイル) | ツリーとルールを修正 |
| `docs/` 直下にトップレベル文書を追加/削除 | `docs/README.md` | 「そのほかのドキュメント」の行を増減 |
| `docs/specs/` 直下のファイル追加/削除 | `docs/specs/README.md` | 変化頻度表に行を増減 |
| `docs/decisions/` に ADR 追加 / 状態変更 / 廃止 | `docs/decisions/README.md` | 一覧表に行追加、状態列を正しく反映 |
| `docs/plans/` / `specs/` サブディレクトリ / `docs/agent-skills/` | — | インデックス不要 (ディレクトリ単位で参照している) |

※ ファイルごとの詳細な一行説明は各サブディレクトリの `README.md` または本 `LAYOUT.md` のツリー内コメントを単一情報源とする。`docs/README.md` には重複して書かない。
