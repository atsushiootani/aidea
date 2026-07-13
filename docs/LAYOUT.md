---
title: docs ディレクトリ構成とファイル配置ルール
description: docs 配下の配置ルール・命名規約・インデックス更新義務・frontmatter 規約を定める SSoT
derived_from: []
syncs_with: []
impacts:
  - docs/README.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

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
├── setup/             # 初回ユーザー向けの導入・セットアップ手順
│   └── getting-started.md
│
├── decisions/         # 設計判断を残す ADR (Architecture Decision Records) の保管場所
│   ├── README.md      # ADR 一覧・追加手順
│   └── NNNN-kebab-title.md
│
├── specs/             # プロダクト仕様 (設計ストック・コードと 1:1 対応)
│   ├── README.md      # 内のインデックス・機能群ごとのサブディレクトリ一覧
│   ├── architecture.md
│   ├── aspects/       # View 親子関係 AA 図 (view-hierarchy.md) · キー操作 · 永続化 · ソート規約 など横断的関心事
│   ├── glossary.md
│   └── <機能群>/       # backchannels / frontchannels / companions / sessions / tools / widgets / window など (→ README.md 参照)
│
├── plans/             # タイムスタンプ付きの実装計画書アーカイブ (git 管理外)
│   └── plan_YYYYMMDDHHmmss.md
│
├── conventions/       # コードを書くときの規約 (コーディングガイドライン)
│   ├── README.md      # conventions 内のインデックス
│   ├── coding-style.md # Swift 規約 / プロパティラッパ並び順 / コメント方針
│   ├── swift.md       # SwiftUI / AppKit (NSView) の使い分けと閉じ込めルール
│   ├── design-principles.md # 設計原則 (Tell Don't Ask / SOLID / GRASP 等)
│   ├── rules.md       # Always / Confirm First / Never
│   ├── testing.md     # テスト戦略 / 手動確認チェックリスト
│   └── implementations/ # 個別機能の実装規約 (focus.md / e2e-key-simulation.md)
│
└── agent-skills/      # agent-skills の入門・スキル構造解説ドキュメント置き場
    ├── getting-started.md
    └── skill-anatomy.md
```

## 配置ルール

新規ドキュメントを追加するときは、用途に該当する節を読んでから書く。
どの節にも当てはまらない用途が出てきたら、先に本ファイルを更新して置き場を定義する。

### 文書レイヤの判定表 ([ADR 0039](./decisions/0039-docs-layer-taxonomy.md))

各層は内容の種類ではなく、**変更トリガ**と**記述する現象**で定義する。「これはどこに書く?」はこの表で判定する。

| 層 | 語る現象 | 読むタイミング | 必要な事前知識 | 変更される契機 |
|---|---|---|---|---|
| **foundation/** | 価値観・目的 | 方向に迷ったとき | なし | 価値観が変わったとき (ほぼ不変) |
| **要求** (GitHub Issues) | 環境の現象 (〜したい) | 実装を始める前 | ドメインだけ | 欲求が変わったとき。実装されたら消費される (フロー) |
| **specs/** | 界面の現象 (システムは〜する / 常に〜が成立) | 実装前に読む・動作確認時に引く | glossary の用語のみ (コード知識ゼロ) | 挙動を変えたとき (コードと同時) |
| **conventions/** | マシン内部 (どう書くか) | 実装中に引く | コードベースの知識 | 実装方法を変えたとき |
| **decisions/** (ADR) | 選択の経緯 (なぜ A でなく B) | あとから経緯を辿るとき | 当時の文脈 | 変更しない (supersede のみ) |

- requirements 層は**設けない**。実装後の要求の残滓は「spec の概要 1〜2 文 + `issue #NN` の出所リンク」として specs に残す
- **変更トリガが違うものを同じファイルに書かない**のが全層共通の原則

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

### `docs/setup/` — 初回ユーザー向けセットアップ手順

- **用途**: Aidea を**初めて手元で動かすまで**の導入ガイドを置く。ビルド・署名・起動・初期設定など「使い始めるための具体的な手順」を扱う
- **判断基準**: コードの書き方は `docs/conventions/`、動作仕様は `docs/specs/`、設計判断は `docs/decisions/` に。`setup/` は「未経験のユーザーが Aidea を使い始められる状態にする」までの操作ガイドだけを置く
- **命名**: kebab-case 全小文字 (`getting-started.md`)
- **インデックス**: ファイルが少ないうちは README なしで運用する。肥大化したら README を追加する

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
- **標準構成**: 「概要 (何ができるか 1〜2 文 + `issue #NN` の出所リンク) → 挙動 (観測可能な動作) → 不変条件・境界 (Always / Never)」の並びを基本とする。概要 + 出所リンクが Aidea における要求のトレーサビリティを担う ([ADR 0039](./decisions/0039-docs-layer-taxonomy.md))

### 実装詳細ルール (specs は実装知識ゼロで読めること)

`specs/` の目的は、**実装を知らない読み手 (未来の自分・他者・AI) が「何が起きるか」と「なぜそうするか」を理解できる**こと。
唯一の判断軸は **「読むのにコードベースの知識が要るか」= 人間の認知負荷** ([issue #95](https://github.com/atsushiootani/aidea/issues/95))。
一律禁止ではなく、**認知負荷を上げる実装識別子は概念表現に置き換え、認知負荷を上げない設計判断は残す**ハイブリッド運用とする。

#### 避ける — 読むのに実装知識が要る (概念表現へ置き換える)

| パターン | 例 | 置き換え例 |
|---|---|---|
| メソッド / 関数シグネチャ | `loadCommand(for:)` / `update(_:)` / `sendMessageWhenReady(_:)` | 「指示書読み込みコマンドを生成する」等の**動詞表現** |
| プロパティラッパ / デコレータ | `@Observable` / `@Published` / `@State` / `@FocusState` | 削除 (挙動に無関係な実装技術) |
| Swift コードブロック | ` ```swift ` で始まるコードブロック / `state.x = y` の写経 | 箇条書き・表で**挙動**を記述 |
| 内部ソースファイルパス | `Services/Foo.swift` / `Views/Bar.swift` | 「〜を担うコンポーネント」等の**役割名** |
| 型名・クラス名の羅列 | 実装コンポーネント表での `WebUIDelegate` / `FooSessionState` 列挙 | 役割ラベル (「UI デリゲート」「Web セッション状態」) |

#### 残してよい — 実装知識がなくても読める (挙動・契約・設計判断)

- 観測可能な挙動、UI 規約、状態遷移、境界 (Always / Never)、データ形式
- **設計判断としての具体値**: タイミング (例 `+5.0s`)、送出するキー / エスケープシーケンス (例 `Ctrl+U` / `ESC O A`)、
  tmux セッション名の命名規則、プロトコル番号など。これらは「なぜそうなるか」に紐づく**仕様**であり、
  コードを知らなくても読める。背景がある場合は該当 ADR にリンクする

#### 不変条件の置き場所は「語る現象」で 3 分岐する ([ADR 0039](./decisions/0039-docs-layer-taxonomy.md))

| 不変条件が語る現象 | 置き場所 | 例 |
|---|---|---|
| 環境の欲求 (〜したい) | Issue / `foundation/vision.md` | 「打った文字が意図した場所に入ってほしい」 |
| 界面の保証 (常に〜が成立) | **specs** の不変条件・境界 (Always / Never) | 「キー入力は常にアクティブ Session だけに届く」 |
| マシン内部の制約 | `conventions/implementations/` かコード近傍 (コメント / assert) | 「firstResponder はアクティブ Session の View 階層配下」 |

specs の Always / Never は**ユーザから観測可能な不変条件**に限る。
「読むのにコードベースの知識が要るか」(認知負荷テスト) は「界面の現象か内部の現象か」の判定と実質同じ。

#### 置き場所

- **実装識別子 (クラス名・メソッド名・ファイルパス) は [`conventions/`](./conventions/README.md) / [`decisions/`](./decisions/README.md) に書いてよい。** specs からはそこへリンクする
- 使い分け: **一度きりの判断の経緯**は ADR (作成後は変更しない凍結文書)。**コードと一緒に進化する実装契約・知見** (ヘルパの使い方、登録・解放の責任、実装に苦労した回避策) は `conventions/` (生きた文書として更新する)。局所的なワークアラウンドはコードコメントでもよい
- **例外**: `architecture.md` / `view-hierarchy.md` はクラス名・View 名・ファイルパスの列挙を許可する (構造の地図が目的のため)

「避ける」パターンは `/aidea.docs-healthcheck` の「実装詳細チェック」で機械的に検出する。「残してよい」具体値は検出対象外。

### 用語の定義と参照リンク (造語には本拠地を 1 つ)

前節で実装識別子を概念語・造語に置き換えると、その造語 (例: 「自動起動シーケンス」「受付可能」) が複数箇所で使われる。
意味がぶれず、読み手が定義に必ずたどり着けるよう、**造語ごとに「定義の本拠地」を 1 つだけ決め、他の出現はそこへリンクする**。

#### 本拠地の選び方 — 広範なら glossary、局所なら機能群 spec

| 語の広がり | 例 | 本拠地 |
|---|---|---|
| **専用の機能群ディレクトリを持つ**語 | Backchannel / Frontchannel | その機能群の `README.md` (インデックス) 冒頭の定義文 |
| **機能群をまたいで頻出**するが専用ディレクトリは持たない語 | Window / Pane / Session / Tool | [glossary.md](./specs/glossary.md) に用語行を追加 |
| **特定の機能群でしか使わない**語 | 「自動起動シーケンス」(claude 圏のみ) | その機能群 spec 内に**定義セクション (見出し) を 1 つ**置き、そこを本拠地にする |

- 局所語を glossary に載せない。glossary が肥大化すると横断語を探しにくくなり、glossary 自体の価値が下がるため。
- 判断軸: 「専用ディレクトリを持つ?」→ 持つならその README。「持たないが機能群をまたぐ?」→ glossary。「またがない?」→ 当該機能群 spec の見出し。

#### リンク義務

- 本拠地**以外**のファイルでその語が**初めて**出てきたら、本拠地の見出しアンカーへ Markdown リンクを張る。
- 同一ファイル内の 2 回目以降・表のヘッダセル・コードブロック内は任意 (読み手は既に本拠地へ到達できるため)。
- 本拠地の見出し直下は、その語が**何を指すか 1 文で定義**してから詳細に入る (見出しアンカーが定義の入口になるように)。

### `docs/plans/` — 実装計画 (git 管理外)

- **用途**: ある時点の実装計画スナップショット。セッション固有の作業メモで、陳腐化しやすいため **`.gitignore` で git 管理から外している**
- **命名**: `plan_YYYYMMDDHHmmss.md`
- **例**: `plan_20260414130000.md`
- **永続化**: 計画から出た重要な設計判断は `docs/decisions/` に ADR として昇格させる (plans 単独では残さない)

### `docs/conventions/` — コードを書くときの規約

- **用途**: 実装者が従うコーディング規約・テスト戦略・設計原則。「何を作るか」ではなく「どう書くか」を扱う
- **現在のファイル**: `coding-style.md` (Swift 規約) / `swift.md` (SwiftUI/NSView 使い分け) / `design-principles.md` (設計思想) / `rules.md` (Always/Never) / `testing.md` (テスト戦略)
- **直下と `implementations/` の使い分け**: 直下にはコードベース**全体にまたがる規約**だけを置く。特定の機能・仕様に紐づく実装規約・実装知見 (例: `focus.md` = フォーカス契約の実装規約、`e2e-key-simulation.md`) は `conventions/implementations/` に置き、対応する spec からリンクする
- **判断基準**: プロダクト動作 (spec) ではなくコードの書き方に関する規約は全てここに置く
- **命名**: kebab-case 全小文字
- **docs の書き方規約**は本ファイル内「frontmatter 規約」節に置く (docs メタ文書なので conventions ではなく LAYOUT.md に集約)

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

---

## frontmatter 規約

`docs/` 配下の Markdown ドキュメントに YAML frontmatter を付け、ドキュメント間の依存関係を機械可読にする。目的は**ドキュメント A を変更したときに関連する B/C の更新漏れを防ぐこと**。

### なぜ frontmatter を付けるのか

- **agent が関連文書を追跡できる**: あるドキュメントを読んだ agent が、どの上流・下流・兄弟ドキュメントを一緒に見るべきかを機械的に判断できる
- **`/aidea.docs-healthcheck` の精度向上**: 双方向リンクの整合性・参照切れを自動検出できる
- **変更の影響範囲を即座に把握できる**: PR レビュー時に「この変更で他のどこを更新すべきか」が一目でわかる

### フィールド定義

#### 全ドキュメント共通

| フィールド | 必須 | 型 | 意味 |
|---|---|---|---|
| `title` | ✅ | string | ドキュメントのタイトル (本文 `#` 見出しと一致させる) |
| `description` | ✅ | string | 1 行の説明。agent が関連性を判断する材料 |
| `derived_from` | ✅ | string[] | **上流** (強): ここを変えたら本文を書き直す必要がある文書 |
| `syncs_with` | ✅ | string[] | **双方向同期**: どちらを変えても相手を更新する必要がある文書 |
| `impacts` | ✅ | string[] | **下流** (強): 自分を変えたら相手も更新すべき文書 |
| `conventions` | ✅ | string[] | 書き方・更新ルールの参照先 (本ファイルと、該当ディレクトリの README.md に更新ルールがあればそれも) |
| `last_updated` | ✅ | string | 最終更新日 (`YYYY-MM-DD`) |

#### ADR (`docs/decisions/`) のみ

| フィールド | 必須 | 型 | 意味 |
|---|---|---|---|
| `status` | ✅ | enum | `提案` / `採用` / `暫定` / `確定` / `廃止` / `置換` |
| `replaces` | 任意 | string[] | この ADR が置き換える過去の ADR |
| `replaced_by` | 任意 | string[] | この ADR を置き換えた新しい ADR |

`specs/` は**ストック情報**として常に確定扱いで、置換されたドキュメントは必ず削除するため、これらのフィールドは付けない。

#### ADR の impacts / syncs_with は常に空

ADR は「過去に下した判断」であり、**作成後に文書内容を変更しない** (ステータス遷移と置換関係だけ更新する)。そのため:

- **ADR 側**: `impacts: []` / `syncs_with: []` で固定
- **他ファイル側**: `impacts` / `syncs_with` に ADR (`docs/decisions/*.md`) を**入れない**
  - 「自分を変えたら ADR を見直す」という関係は ADR が変更されない前提で成立しない
  - ADR は `derived_from` 側にのみ現れる
- 「この ADR は何に影響するか」は**下流 (specs 等) 側の `derived_from` で表現する**
- これにより ADR 側はメンテ不要になり、新しい仕様が古い ADR を参照しても ADR ファイルを編集する必要がない

このルールは [`/aidea.docs-healthcheck`](../../.claude/commands/aidea.docs-healthcheck.md) の frontmatter 整合性チェックで機械的に検証される。

### 依存関係の書き分け

3 つの関係フィールドを混同しないための判断基準。

#### `derived_from` (上流 → 自分 / 強)

**判定**: 「相手を変更したら、自分の本文も書き直す必要があるか?」

- ✅ ADR の判断内容が自分の仕様を規定している
- ✅ architecture.md の設計方針が自分の詳細仕様を規定している
- ❌ 本文中で軽く参照しているだけ (→ 参照先リンクで十分)

#### `syncs_with` (双方向 / 強)

**判定**: 「どちらを変更しても、相手も同時に更新が必要か?」

- ✅ aspects の集約ビューと個別機能群の spec (keybindings ↔ tools/*)
- ✅ インデックスファイルと配下の個別ファイル (aspects/README ↔ aspects/*.md)
- ❌ 片方向の派生関係 (→ `derived_from` または `impacts`)

#### `impacts` (自分 → 下流 / 強)

**判定**: 「自分を変更したら、相手も更新すべきか? (逆は不要)」

- ✅ 自分が規範で、下流ドキュメントが実装詳細を書く関係
- ❌ 下流を変更しても自分は変わらない弱い関係

#### どれにも当てはまらないリンク

本文中で参照しているだけのリンク (用語集・関連仕様への軽い言及) は frontmatter に書かず、Markdown リンクのみで扱う。リンク切れは healthcheck で別途チェックする。

### 記述ルール

#### パスの書き方

- **リポジトリルートからの相対パス**で記述する (`docs/specs/architecture.md`)
- ディレクトリ全体を指す場合は末尾にスラッシュ (`docs/specs/tools/`)
- **ワイルドカード `<dir>/*`** でディレクトリ直下の全 Markdown ファイルを指せる
  - 例: `docs/specs/aspects/*` は `keybindings.md` と `persistence.md` を含む
  - インデックスファイル (README.md) が配下を束ねる場合に使う
  - ワイルドカードが**自分自身を含む場合は自動的に除外**される (例: `docs/specs/sessions/ui-rules.md` の `impacts` が `docs/specs/sessions/*` でも自分自身は指さない)
  - 個別ファイルを特別扱いしたい場合はワイルドカードではなく個別に列挙する
- 他のドキュメントから参照されやすいので、ファイルを**リネーム/削除したら参照元を全て更新**する

#### 空配列の扱い

関係がないフィールドは `[]` で明示する。省略しない。

```yaml
syncs_with: []
impacts: []
```

理由: 「考慮した上で関係なし」と「書き忘れ」を区別するため。

#### `last_updated`

- 本文を意味的に変更したタイミングで更新する
- typo 修正・リンク切れ修正など**内容に影響しない編集では更新しない**
- 形式は `YYYY-MM-DD` (ISO 8601)

#### `title` と `description`

- `title`: 本文の `#` 見出しと完全一致させる
- `description`: 50〜120 文字程度。**agent が関連性判断に使う**ので具体的に書く
  - ❌ 「仕様書」「ドキュメント」
  - ✅ 「UserDefaults / Keychain / .aidea/ のデータ永続化仕様を機能群横断で集約」

### テンプレート

#### specs/ 用

```yaml
---
title: <タイトル>
description: <50-120 文字の具体的な説明>
derived_from:
  - docs/decisions/NNNN-*.md
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-MM-DD
---
```

#### decisions/ (ADR) 用

```yaml
---
title: <タイトル>
description: <50-120 文字の具体的な説明>
status: 提案
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-MM-DD
---
```

### 適用範囲と導入状況

| ディレクトリ | 適用状況 |
|---|---|
| `docs/` 直下 (README / LAYOUT) | ✅ 完了 (2026-04-17) |
| `docs/specs/` 直下 (README / architecture / glossary) | ✅ 完了 (2026-04-17) |
| `docs/specs/aspects/` | ✅ 完了 (2026-04-17) |
| `docs/specs/tools/` | ✅ 完了 (2026-04-17) |
| `docs/specs/sessions/` | ✅ 完了 (2026-04-17) |
| `docs/specs/backchannels/` | ✅ 完了 (2026-04-17) |
| `docs/specs/frontchannels/` | ✅ 完了 (2026-04-17) |
| `docs/specs/companions/` | ✅ 完了 (2026-04-17) |
| `docs/specs/widgets/` | ✅ 完了 (2026-04-17) |
| `docs/specs/skills/` | ✅ 完了 (2026-05-06) |
| `docs/specs/window/` | ✅ 完了 (2026-04-17) |
| `docs/foundation/` | ✅ 完了 (2026-04-17) |
| `docs/setup/` | ✅ 完了 (2026-05-11) |
| `docs/agent-skills/` | ✅ 完了 (2026-04-17) |
| `docs/decisions/` | ✅ 完了 (2026-04-17) — status フィールドを本文から frontmatter に移行 |
| `docs/conventions/` | ✅ 完了 (2026-07-13) — `implementations/` 含む |

全ディレクトリ適用済み。`/aidea.docs-healthcheck` で未適用ファイルをフラグする拡張は別途検討。
