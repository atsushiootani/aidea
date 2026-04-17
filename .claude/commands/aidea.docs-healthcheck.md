---
description: docs/specs と docs/decisions のヘルスチェックを実施する (矛盾 / 未定義参照 / stale / 抜け漏れの確認)
---

# docs ヘルスチェック

Aidea の設計ドキュメント (`docs/specs/` と `docs/decisions/`) の健全性を一括で確認する。各領域の詳細基準は以下の SSoT に従う。

- [docs/specs/README.md](../../docs/specs/README.md) の「## ヘルスチェック」節
- [docs/decisions/README.md](../../docs/decisions/README.md) の「## ヘルスチェック」節

## やること

### 0. 前提読み込み (必須)

チェックを始める前に、以下 2 ファイルを必ず読んで docs 全体の地図と規約を把握する。

- [docs/README.md](../../docs/README.md) — docs 配下のインデックス (どこに何があるかの全体像)
- [docs/LAYOUT.md](../../docs/LAYOUT.md) — 配置ルール・命名規約・インデックス更新義務・**frontmatter 規約** (`derived_from` / `syncs_with` / `impacts` / `conventions` 等のフィールド定義)

これらを読むことで、後続のチェックで「参照切れ」「配置違反」「frontmatter の整合性」を正しく判定できる。

### 1. specs ヘルスチェック

[docs/specs/README.md](../../docs/specs/README.md) の「## ヘルスチェック」節のチェック項目 (1〜6) を順に適用する:

- specs ドキュメント同士の矛盾
- [docs/decisions/](../../docs/decisions/) の ADR との矛盾 (ADR 優先。暫定/提案状態は指摘レベル下げる)
- `Aidea/Aidea/` 配下の実装との矛盾 (stale specs)
- コードにあるのに specs に書かれていない機能・概念
- 永続化データの抜け ([docs/specs/aspects/persistence.md](../../docs/specs/aspects/persistence.md) との突き合わせ)
- aspects（横断的関心事）との整合性 — 機能群の変更が [docs/specs/aspects/](../../docs/specs/aspects/README.md) に反映されているか（詳細は aspects/README.md の更新ルールを参照）

### 2. decisions ヘルスチェック

[docs/decisions/README.md](../../docs/decisions/README.md) の「## ヘルスチェック」節のチェック項目 (1〜3) を順に適用する:

- ADR 同士の矛盾 (旧 ADR への「廃止」「置換 (→ NNNN)」「進化予定」注記の有無もチェック)
- 未定義参照 (ADR 本文が言及する概念・ファイルが定義されていない / 削除済みファイル参照)
  - ADR 同士の参照 / `docs/specs/*` の実在ファイル / 外部パッケージ / その ADR 内完結の概念は除外
- 状態 (status) 整合性 (README 一覧表と各 ADR の `**状態**` フィールドの一致)

### 3. frontmatter 整合性チェック

対象範囲: frontmatter が適用済みのファイル (現在は `docs/specs/aspects/` 配下)。LAYOUT.md の「適用範囲と導入状況」で `✅ 完了` になっているディレクトリが対象。

以下を順にチェックする:

- **必須フィールドの欠落** — `title` / `description` / `derived_from` / `syncs_with` / `impacts` / `conventions` / `last_updated` が揃っているか (ADR なら加えて `status`)
- **参照切れ** — `derived_from` / `syncs_with` / `impacts` / `conventions` / `replaces` / `replaced_by` に書かれたパス (個別ファイル・ワイルドカード `<dir>/*`・末尾スラッシュ `<dir>/`) が実在するか
- **双方向性 (syncs_with)** — A が `syncs_with: [B]` を宣言しているなら、B 側にも `syncs_with: [A]` (またはワイルドカードで A を含む指定) があるか
- **空配列の明示** — 関係がないフィールドは `[]` で明示されているか (省略禁止)
- **規約違反** — `title` が本文 `#` 見出しと一致するか / `last_updated` が `YYYY-MM-DD` 形式か / ADR 専用フィールド (`status` / `replaces` / `replaced_by`) が specs/ に紛れ込んでいないか
- **conventions の必須参照** — `docs/LAYOUT.md` を必ず含んでいるか

詳細ルールは [docs/LAYOUT.md](../../docs/LAYOUT.md) の「frontmatter 規約」節を SSoT とする。

### 4. 結果の報告

- **specs セクション** / **decisions セクション** / **frontmatter セクション** に分けて、フラグが立った項目を列挙する
  - 各項目: **ファイル (file:line)** / **フラグ種別** / **問題の要点** / **README の対応方針に沿った提案**
- 各 README の「フラグへの対応」表に従い、ユーザ確認が必要なものは問い合わせ、明確なものは修正提案を出す
- frontmatter の違反は LAYOUT.md の規約に沿って修正提案を出す
- 全領域フラグゼロなら**サイレント pass** (「問題なし」と短く報告するだけ)

## スコープ

- **引数や会話で明示的にスコープが指定された場合** → その範囲のみを対象とする
- **スコープが明示されない場合** → 今回修正されたドキュメント・コード (`git diff` で変更のあるファイル) を中心に調べる。変更ファイルが参照・被参照するドキュメントも対象に含める

## 注意

- specs はストック情報 (コードと 1:1 対応) のみが対象。フロー情報 (ロードマップ・アイデア) は GitHub Issues 側なので対象外。
- ADR が「暫定」「提案」ステータスのものは矛盾指摘のレベルを下げる。
- フラグが立ったら **その PR 内で解消する** (別 PR に持ち越さない)。
