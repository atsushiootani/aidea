---
description: docs/specs と docs/decisions のヘルスチェックを実施する (矛盾 / 未定義参照 / stale / 抜け漏れの確認)
---

# docs ヘルスチェック

Aidea の設計ドキュメント (`docs/specs/` と `docs/decisions/`) の健全性を一括で確認する。各領域の詳細基準は以下の SSoT に従う。

- [docs/specs/README.md](../../docs/specs/README.md) の「## ヘルスチェック」節
- [docs/decisions/README.md](../../docs/decisions/README.md) の「## ヘルスチェック」節

## やること

### 1. specs ヘルスチェック

[docs/specs/README.md](../../docs/specs/README.md) の「## ヘルスチェック」節のチェック項目 (1〜5) を順に適用する:

- specs ドキュメント同士の矛盾
- [docs/decisions/](../../docs/decisions/) の ADR との矛盾 (ADR 優先。暫定/提案状態は指摘レベル下げる)
- `Aidea/Aidea/` 配下の実装との矛盾 (stale specs)
- コードにあるのに specs に書かれていない機能・概念
- 永続化データの抜け ([docs/specs/persistence.md](../../docs/specs/persistence.md) との突き合わせ)

### 2. decisions ヘルスチェック

[docs/decisions/README.md](../../docs/decisions/README.md) の「## ヘルスチェック」節のチェック項目 (1〜3) を順に適用する:

- ADR 同士の矛盾 (旧 ADR への「廃止」「置換 (→ NNNN)」「進化予定」注記の有無もチェック)
- 未定義参照 (ADR 本文が言及する概念・ファイルが定義されていない / 削除済みファイル参照)
  - ADR 同士の参照 / `docs/specs/*` の実在ファイル / 外部パッケージ / その ADR 内完結の概念は除外
- 状態 (status) 整合性 (README 一覧表と各 ADR の `**状態**` フィールドの一致)

### 3. 結果の報告

- **specs セクション** と **decisions セクション** に分けて、フラグが立った項目を列挙する
  - 各項目: **ファイル (file:line)** / **フラグ種別** / **問題の要点** / **README の対応方針に沿った提案**
- 各 README の「フラグへの対応」表に従い、ユーザ確認が必要なものは問い合わせ、明確なものは修正提案を出す
- 両領域ともフラグゼロなら**サイレント pass** (「問題なし」と短く報告するだけ)

## 注意

- specs はストック情報 (コードと 1:1 対応) のみが対象。フロー情報 (ロードマップ・アイデア) は GitHub Issues 側なので対象外。
- ADR が「暫定」「提案」ステータスのものは矛盾指摘のレベルを下げる。
- フラグが立ったら **その PR 内で解消する** (別 PR に持ち越さない)。
