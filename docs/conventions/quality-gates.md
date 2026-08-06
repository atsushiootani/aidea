---
title: 品質ゲート (機械検査)
description: scripts/ 配下の機械検査 (ビルド / ユニットテスト / docs リンク / specs 実装詳細) の内容と、検証欄を人手で書かせない運用ルール
derived_from: []
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-08-06
---

# 品質ゲート (機械検査)

**本当に守らせたいものはプロンプトではなく機械検査にする**。
規約に書いただけのルールは守られる確率が上がるだけで、保証にはならない。
ここでは「機械で守れるもの」を `scripts/` 配下の検査に落とし、
「機械で守れないもの」(実機での手触り) はそう明示することを定める。

## ゲート一覧

| スクリプト | 検査内容 | 落ちる条件 |
|---|---|---|
| `scripts/run-tests.sh` | ユニットテスト (`AideaTests`) | 1 件でも失敗 / 0 件 |
| `scripts/check-docs-links.py` | `docs/` 内の Markdown リンクとアンカーの実在 | リンク切れ / アンカー切れが 1 件でもある |
| `scripts/check-spec-impl-details.py` | [実装詳細ルール](../LAYOUT.md#実装詳細ルール-specs-は実装知識ゼロで読めること) | ERROR パターンが 1 件でもある |
| `scripts/gate.sh` | 上記 + ビルドをまとめて実行し、検証欄を生成 | いずれかが落ちたら |

```bash
scripts/gate.sh          # 全ゲート (ビルド + テスト + docs)
scripts/gate.sh --fast   # docs 検査のみ (docs だけ変更したとき)
```

## 個別の注意

### ユニットテスト — 素の `xcodebuild test` は使わない

UI テストターゲット (`AideaUITests`) は runner がハングし
`The test runner hung before establishing connection` で必ず失敗するため、
`-only-testing:AideaTests` でユニットテストのみに絞っている。
署名証明書の期限に左右されないよう `CODE_SIGNING_ALLOWED=NO` で走らせる。

### 実装詳細検査 — ERROR と WARN を分ける理由

**誤検知するゲートは無視されるようになる**ため、
誤検知しないパターンだけを ERROR (ゲートを落とす) にしている。

| 区分 | パターン | 理由 |
|---|---|---|
| ERROR | Swift コードブロック / プロパティラッパ / ラベル付きメソッドシグネチャ (`foo(bar:)`) | いずれも Swift 特有で、仕様本文に正当に現れることがない |
| WARN | `.swift` ファイル名 / 引数なし呼び出し風 (`foo()`) | git の出力例・パス検出 regex の例示・hook の対象条件など、**実装への参照ではない例示**と機械的に区別できない |

例外ファイル (`architecture.md` / `aspects/view-hierarchy.md`) は
LAYOUT.md の規定どおり検査対象から外す。

## 検証欄は人手で書かない

`gate.sh` は最後に PR / 完了報告へ貼る「検証」欄を生成する。**この出力をそのまま使う**。

```
## 検証

- ビルド: 成功
- ユニットテスト: 33 passed / 0 failed
- docs リンク検査: OK
- specs 実装詳細検査: OK
- **実機確認: 未実施 (確認できるのは人間だけ)**
```

- **実機確認の行は常に「未実施」で出力される**。実際に触って確認した人だけが、その行を手で書き換える
- 自分が実行していない検証を、実行したように書かない
- ユーザの短い承認 (「ok」「いいね」) を、個別項目の検証根拠にしない

この運用は、未検証の項目を「実機確認済み」と PR 本文に書いた事故 (PR #276 / #277 / #278) を
構造的に防ぐために設けた。人手で書ける限り同じ事故は再発するので、**生成物に置き換える**。

## 関連

- [../LAYOUT.md](../LAYOUT.md#実装詳細ルール-specs-は実装知識ゼロで読めること) — specs の実装詳細ルール (検査の根拠)
- [testing.md](./testing.md) — テスト戦略と手動確認チェックリスト
- [rules.md](./rules.md) — Always / Confirm First / Never
