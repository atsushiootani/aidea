---
title: "0039: docs の文書レイヤを「変更トリガ」と「記述する現象」で分類する"
description: foundation / specs / conventions / decisions の 4 層を変更トリガと記述する現象 (環境・界面・内部) で定義し、requirements 層は設けず Issues + vision + spec 概要に分散させる判断
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# 0039: docs の文書レイヤを「変更トリガ」と「記述する現象」で分類する

**日付**: 2026-07-13 / **issue**: #95

## 背景

issue #95 (specs から実装詳細を除去し人間の認知負荷を下げる) を受けてハイブリッドルール
(認知負荷を上げる実装識別子は概念表現へ、設計判断の具体値は残す) を導入し、
focus-contract.md を「spec (要件・不変条件)」と「conventions/implementations/ (実装規約)」に分割した。

この過程で次の疑問が生じた:

- specs に書くべきものは何か。**不変条件は要求仕様ではなさそうなのに、specs に置くのが適正に感じる**のはなぜか
- foundation / requirements / specs / conventions はどう分かれるのか。
  Aidea には requirements 層が存在しないが、それでよいのか

要求工学の標準 (ISO/IEC/IEEE 29148)、WRSPM 参照モデル (Jackson & Zave / Gunter)、
Design by Contract (Meyer)、Diátaxis、arc42、Parnas "A Rational Design Process"、
AI 時代の spec 駆動開発 (Amazon Kiro / GitHub Spec Kit) を調査し、
併せて docs/ 全 65 spec ファイルの記述実態を調査した。

### 調査で判明した事実

1. **不変条件の位置づけ (WRSPM)**: 文書は「どの現象について語るか」で分類できる。
   - **要求 (R)** = 環境の現象のみで書く (「打った文字が意図した場所に入ってほしい」)
   - **仕様 (S)** = 環境とシステムの**界面 (共有現象)** で書く (「キー入力は常にアクティブ Session だけに届く」)
   - **設計・実装** = マシン内部の現象 (「firstResponder はアクティブ Session の View 階層配下」)

   不変条件は「要求を満たすためにシステムが界面で立てる誓約 (契約)」であり、
   要求ではないが仕様の中核である (Z / VDM 等の形式仕様でも state invariant は仕様の主成分)。
   issue #95 の判断軸「読むのにコードベースの知識が要るか」は、
   WRSPM の「共有現象か内部現象か」テストと実質同じものだった。

2. **specs の実態**: 65 ファイルの内容は「観測可能な挙動」が大半、「不変条件・契約」が中程度、
   「要求 (〜したい / 〜すべき)」はほぼゼロ。Always/Never は全て ADR かバグ修正由来の
   設計判断・不変条件であり、要求ではなかった。

3. **要求の所在**: 要求に相当する情報は既に 3 箇所に分散している。
   vision.md (スコープの縁・成功基準) + GitHub Issues (個別要望のフロー) +
   ADR の背景セクション (設計を動かした問題意識)。
   トレーサビリティは「要求 → 実装」ではなく「実装済み仕様に `issue #NN` で出所リンクを張る」逆方向。

4. **全流派共通の鉄則**: 「**変更トリガが違うものを同じファイルに書かない**」。
   ADR がイミュータブル (supersede のみ) なのに対し要求は生きて更新されるため、
   要求の SSoT を ADR に置かない、等はこの原則の系。

## 決定

### 1. 文書レイヤは「変更トリガ」と「記述する現象」で定義する

| 層 | 語る現象 | 読むタイミング | 必要な事前知識 | 変更される契機 |
|---|---|---|---|---|
| **foundation** | 価値観・目的 | 方向に迷ったとき | なし | 価値観が変わったとき (ほぼ不変) |
| **要求** (Issues 等) | 環境の現象 (〜したい) | 実装を始める前 | ドメインだけ | 欲求が変わったとき。実装されたら消費される (フロー) |
| **specs** | 界面の現象 (システムは〜する / 常に〜が成立) | 実装前に読む・動作確認時に引く | glossary の用語のみ (コード知識ゼロ) | 挙動を変えたとき (コードと同時) |
| **conventions** | マシン内部 (どう書くか) | 実装中に引く | コードベースの知識 | 実装方法を変えたとき |
| **decisions** (ADR) | 選択の経緯 (なぜ A でなく B) | あとから経緯を辿るとき | 当時の文脈 | 変更しない (supersede のみ) |

### 2. requirements 層は設けない

要求者 = 実装者の個人開発では、要求は「実装されたら消費されるフロー情報」であり、
GitHub Issues がその容れ物として機能している (LAYOUT の「ストック = specs / フロー = Issues」)。
実装後の要求の残滓は「spec の概要 1〜2 文 + `issue #NN` の出所リンク」として specs に残す。
これは Parnas の「合理的だったかのように文書を事後整備する」運用の実践である。

### 3. 不変条件は「語る現象」で置き場所を 3 分岐する

| 不変条件が語る現象 | 置き場所 | 例 |
|---|---|---|
| 環境の欲求 | Issue / vision.md | 「打った文字が意図した場所に入ってほしい」 |
| 界面の保証 (常に〜) | **specs** の不変条件・境界 (Always/Never) | 「キー入力は常にアクティブ Session だけに届く」 |
| マシン内部の制約 | conventions/implementations/ かコード近傍 (コメント / assert) | 「firstResponder はアクティブ Session の View 階層配下」 |

specs の Always/Never は「ユーザから観測可能な不変条件」に限る。

## 帰結

- 「これはどこに書く?」が変更トリガと現象の 2 軸で機械的に判定できる。判定表は docs/LAYOUT.md に反映する
- issue #95 のハイブリッドルール (実装詳細ルール) に理論的裏付けが付く
  (認知負荷テスト = 共有現象テスト)
- focus-contract.md の spec / conventions/implementations/ 分割はこの分類の適用第 1 号
- specs に「〜すべき」(要求) を書かない現行運用が明文化される。
  要求を長期保存したい場合は Issue に書き、実装時に spec の概要 + 出所リンクへ変換する

## 参考

- [WRSPM: Gunter et al. "A Reference Model for Requirements and Specifications" (ICRE 2000)](http://egunter.cs.illinois.edu/papers/ICRE2000.pdf)
- [Meyer "Applying Design by Contract"](https://se.inf.ethz.ch/~meyer/publications/computer/contract.pdf)
- [Parnas & Clements "A Rational Design Process: How and Why to Fake It"](https://users.ece.utexas.edu/~perry/education/SE-Intro/fakeit.pdf)
- [Diátaxis](https://diataxis.fr/) / [arc42](https://arc42.org/overview)
- [Amazon Kiro: Specs](https://kiro.dev/docs/specs/) / [GitHub Spec Kit](https://github.com/github/spec-kit)
