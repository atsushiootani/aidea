# docs ディレクトリ構成とファイル配置ルール

新しいドキュメントを追加する際に「どこに、どんな名前で置くか」で迷わないための単一参照先。
変更が生じたらこのファイルも必ず更新すること。

## ツリー構造 (全体像)

```
docs/
├── LAYOUT.md          # 本ファイル。docs配下の配置ルールと命名規約
├── README.md          # docs 全体のインデックス
│
├── foundation/        # プロジェクトの土台 (動機・原則)
│   ├── README.md
│   └── vision.md      # 作る動機とプロジェクトの原則
│
├── decisions/         # 設計判断を残す ADR (Architecture Decision Records) の保管場所
│   ├── README.md      # ADR 一覧・追加手順
│   └── NNNN-kebab-title.md
│
├── specs/             # プロダクト仕様 (設計ストック・コードと 1:1 対応)
│   ├── README.md      # 内のインデックス・機能群ごとのサブディレクトリ一覧
│   ├── architecture.md
│   ├── persistence.md
│   ├── glossary.md
│   └── <機能群>/       # backchannels / frontchannels / companions / sessions / tools / window など (→ README.md 参照)
│
├── plans/             # タイムスタンプ付きの実装計画書アーカイブ (git 管理外)
│   └── plan_YYYYMMDDHHmmss.md
│
├── conventions/       # コードを書くときの規約 (コーディングガイドライン)
│   ├── README.md      # conventions 内のインデックス
│   ├── coding-style.md # Swift 規約 / プロパティラッパ並び順 / コメント方針
│   ├── design-principles.md # 設計原則 (Tell Don't Ask / SOLID / GRASP 等)
│   └── testing.md     # テスト戦略 / 手動確認チェックリスト
│
└── agent-skills/      # agent-skills の入門・スキル構造解説ドキュメント置き場
    ├── getting-started.md
    └── skill-anatomy.md
```

## 配置ルール

新規ドキュメントを追加するときは、用途に該当する節を読んでから書く。
どの節にも当てはまらない用途が出てきたら、先に本ファイルを更新して置き場を定義する。

### 共通ルール

- 拡張子は `.md` (図表のみ `.drawio` / `.svg`)
- ファイル名・ディレクトリ名は全小文字の kebab-case (例外: ルート直下のメタ文書 `README.md` / `LAYOUT.md`)
- 日本語ファイル名は使わない (リンク切れ・ツール非対応回避)
- **ディレクトリ名の単複**: インスタンスが複数あり得るものは複数形 (`tools/` `sessions/` `frontchannels/` `backchannels/` `companions/` `decisions/` `plans/` `conventions/`)。1 つしか存在しないものは単数形 (`window/` `foundation/`)
- 1 トピック 1 ファイル。肥大化したらサブディレクトリを切って分割する
- 新しいサブディレクトリを作ったら本ファイルのツリーと配置ルールを同時に更新する

### `docs/` 直下 — メタ文書のみ

- **用途**: `README.md` (docs インデックス) と `LAYOUT.md` (本ファイル) のメタ文書だけを置く
- **命名**: 英大文字 `.md` (`README.md` `LAYOUT.md`)
- **判断基準**: カテゴリ化できるコンテンツは直下ではなくサブディレクトリへ。新規トップレベル文書を追加する場合は、まず適切なサブディレクトリを検討する

### `docs/foundation/` — プロジェクトの土台 (動機・原則)

- **用途**: 長寿命で、判断に迷ったときに立ち返る動機・原則・思想を置く
- **現在のファイル**: `vision.md` (作る動機とプロジェクトの原則)
- **判断基準**: 個別設計判断は `docs/decisions/` へ、確定仕様は `docs/specs/` へ、規約は `docs/conventions/` へ。それらより一段上の「プロジェクトの土台」に相当するものを置く
- **命名**: kebab-case 全小文字

### `docs/decisions/` — 設計判断 (ADR)

- **用途**: 「なぜ A でなく B を選んだか」「後からひっくり返すと影響が大きい決定」を1件1ファイルで記録。既存 ADR の更新で済む場合は新規作成しない
- **命名**: `NNNN-kebab-title.md` (4桁連番)
- **例**: `0013-session-as-first-class-object.md`

### `docs/specs/` — プロダクト仕様 (設計ストック)

- **用途**: Aidea の**現時点の設計仕様**を記述する。`specs/` + `conventions/` を読めば同等のコードベースが再現できる厳密さを目指す
- **ストック情報のみ**: scope / MVP / 実装スケジュール / 未実装アイデアなどの**フロー情報は含めない** (それらは GitHub Issues / Milestones で管理)
- **構成**: トップレベル (`architecture.md` / `glossary.md`) と **機能群ごとのサブディレクトリ**で構成される。現在のサブディレクトリ一覧は [specs/README.md](./specs/README.md) を参照。
- **新しい機能群を追加するとき**: `specs/<新機能群>/` を切って `README.md` を置き、`specs/README.md` の一覧表に1行追加する (本ファイルの更新は不要)
- **命名**: kebab-case 全小文字 (`recommend-mode.md` `scene.md`)

### `docs/plans/` — 実装計画 (git 管理外)

- **用途**: ある時点の実装計画スナップショット。セッション固有の作業メモで、陳腐化しやすいため **`.gitignore` で git 管理から外している**
- **命名**: `plan_YYYYMMDDHHmmss.md`
- **例**: `plan_20260414130000.md`
- **永続化**: 計画から出た重要な設計判断は `docs/decisions/` に ADR として昇格させる (plans 単独では残さない)

### `docs/conventions/` — コードを書くときの規約

- **用途**: 実装者が従うコーディング規約・テスト戦略・設計原則。「何を作るか」ではなく「どう書くか」を扱う
- **現在のファイル**: `coding-style.md` (Swift 規約) / `design-principles.md` (設計思想) / `testing.md` (テスト戦略)
- **判断基準**: プロダクト動作 (spec) ではなくコードの書き方に関する規約は全てここに置く
- **命名**: kebab-case 全小文字

### `docs/agent-skills/` — agent-skills 関連の参照資料

- **用途**: プロジェクトルートの `skills/` に配置した agent-skills の入門・解説資料
- **命名**: kebab-case 全小文字 (`getting-started.md` `skill-anatomy.md`)

### GitHub で管理するもの (docs/ には置かない)

以下は `docs/` 配下で Markdown 管理せず、GitHub 側で扱う。Markdown での二重管理は避ける。

- **個別アイデア・機能要望** → GitHub **Issues** (`enhancement` ラベル)
- **バグ** → GitHub Issues (`bug` ラベル)

昇格フロー: `Issue (enhancement)` → `docs/specs/` に仕様追記 → 実装 → close。
永続的にやらないと決めたものは Issue close + `wontfix`、プロダクトとして永続的にやらないなら [foundation/vision.md](./foundation/vision.md) の「やらないこと」、コード実装の禁止パターンなら [conventions/rules.md](./conventions/rules.md) の Never に追記する。

## インデックス更新の義務

**ファイルを追加・削除・リネームしたら、以下の該当 README を必ず同じコミットで更新する**。
放置するとインデックスが実体と乖離する。

| 対象 | 更新する README | 更新内容 |
|---|---|---|
| 本ファイルのツリーに出てくるディレクトリ/代表ファイルを変更 | `docs/LAYOUT.md` (本ファイル) | ツリーとルールを修正 |
| `docs/foundation/` のファイル追加/削除 | `docs/foundation/README.md` | 一覧表に行を増減 |
| `docs/specs/` 直下のファイル追加/削除 | `docs/specs/README.md` | 一覧表に行を増減 |
| `docs/specs/<機能群>/` にサブディレクトリ新設 | `docs/specs/README.md` + 新設したサブディレクトリの `README.md` | 両方に一覧を書く |
| `docs/specs/<機能群>/` 内のファイル追加/削除 | 該当サブディレクトリの `README.md` | 一覧表に行を増減 |
| `docs/conventions/` のファイル追加/削除 | `docs/conventions/README.md` | 一覧表に行を増減 |
| `docs/decisions/` に ADR 追加 / 状態変更 / 廃止 | `docs/decisions/README.md` | 一覧表に行追加、状態列を正しく反映 |
| `docs/plans/` / `specs/` サブディレクトリ / `docs/agent-skills/` | — | インデックス不要 (ディレクトリ単位で参照している) |

※ ファイルごとの詳細な一行説明は各サブディレクトリの `README.md` または本 `LAYOUT.md` のツリー内コメントを単一情報源とする。`docs/README.md` には重複して書かない。
