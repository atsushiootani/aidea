---
title: Session フォーカス契約
description: キー入力が常にアクティブ Session だけに届くことを保証する不変条件と 3 つの契約 (C1 / C2 / C3)。履行方法の実装規約は conventions/implementations/focus.md に分離
derived_from:
  - docs/decisions/0012-keyboard-focus-dual-path.md
  - docs/decisions/0013-session-as-first-class-object.md
  - docs/decisions/0018-session-and-state-separation.md
  - docs/decisions/0020-session-focus-bridge.md
syncs_with:
  - docs/specs/sessions/session.md
  - docs/specs/sessions/active-session.md
impacts:
  - docs/specs/sessions/ui-rules.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# Session フォーカス契約

**フォーカス契約**とは、複数の Session が並ぶ Window で**キー入力が常に「アクティブな Session」だけに届く**ことを保証するための取り決め (不変条件 + 契約 C1 / C2 / C3) のこと。

本ファイルは **Session 間の一貫性** (要件・不変条件・契約の意味論) だけを対象とする。
契約をコードでどう履行するか (ブリッジヘルパ・View 参照の登録責任・クリックモニタの実装) は
[conventions/implementations/focus.md](../../conventions/implementations/focus.md) を参照。
Session アクティブ化の意味論は [active-session.md](./active-session.md) を参照。

---

## 要件 (観測可能な挙動)

- キー入力は常にアクティブ Session に届く。**非アクティブ Session に届いてはならない**
- Session 内部のどこをクリックしても、その Session がアクティブになる
  (内部 View がクリックを自分で消費する種別 — Web / ターミナル等 — でも成立する)
- タブ切替・ペイン移動・タブクローズの後も、キー入力の宛先が迷子にならない

## 不変条件

任意の時点で以下が成立していなければならない:

- **I1 (排他性)**: アクティブ扱いの Session は高々 1 つである
- **I2 (整合性)**: キー入力を受け取る View は、常にアクティブ Session の View 階層配下に属する
- **I3 (空許容)**: 「アクティブ Session は存在するが、その内部のどの View もキー入力を受けていない」状態は許される

I2 が破れると「アクティブ Session は B のはずなのに、キー入力が Session A に届く」という矛盾が起きる。本契約はこれを防ぐために存在する。

---

## 契約

不変条件を、Session のライフサイクル上の 3 つのタイミングで履行する。

| 契約 | タイミング | 内容 |
|---|---|---|
| **C1 アクティブ化時の反映** | アクティブ Session が切り替わった瞬間 | 新しいアクティブ Session が、キー入力の受け手を自分の配下に移す |
| **C2 非アクティブ化時の解除** | Session が非アクティブ化された瞬間 | 自分が握っているキー入力の受け手を解放する。ただし**自分が握っている場合のみ** |
| **C3 View 破棄時の解除** | Session の View が画面から消えるとき | C2 と同じ解放を行う |

**C2 の「自分が握っている場合のみ」判定は必須**。次にアクティブ化された Session が契約 C1 で既にキー入力の受け手を取得済みの場合があり、無条件に解放すると奪い返してしまう。この判定により、C1 と C2 の発火順序がどちらであっても最終状態は「新しいアクティブ Session がキー入力を受ける」に収束する。

### 契約履行による不変条件の保証

- **I1** は「アクティブ Session の識別子が Window 全体で単一値である」ことによって自動的に保証される
- **I2** は 契約 C1 (アクティブ化時にアクティブ Session 配下へ移す) と 契約 C2 (非アクティブ化時に他 Session 配下へ残さない) の組み合わせで保証される
- **I3** は 契約 C2・C3 が生み出す「どの Session もキー入力を受けていない」状態を明示的に許容することで破れを防ぐ

---

## 履行方法 (2 経路)

契約の履行方法は、Session 内部の View 技術によって 2 経路ある ([ADR 0012](../../decisions/0012-keyboard-focus-dual-path.md))。

| 経路 | 対象 | 概要 |
|---|---|---|
| **AppKit 系** | Terminal / Claude / Web / Filer / Git / GitDiff / Preview の NSView 系コンテンツ | フォーカス制御を専用のブリッジヘルパに委譲する ([ADR 0020](../../decisions/0020-session-focus-bridge.md)) |
| **純 SwiftUI 系** | Kit / Preview の純 SwiftUI コンテンツ | アクティブフラグ 1 つを持ち、SwiftUI のフォーカスバインドに委譲する |

ヘルパの操作・View 参照の登録責任・レイヤごとの責務分担・クリック検知 (クリックモニタ) の実装と解放ルールは、実装規約として [conventions/implementations/focus.md](../../conventions/implementations/focus.md) に定める。

---

## 本仕様の範囲外

以下は本ファイルで扱わない。

- **Session 内部の View 同士のフォーカス調整** — 1 つの Session が内部に複数のフォーカス可能 View を持つ場合の、Session 内でのフォーカス移動
- **ユーザー操作由来のフォーカス変化を Session 側の状態に追従させる経路** — 内部 View がクリック等でキー入力の受け手になったときの追従
- **契約履行の実装コード・実装規約** — [conventions/implementations/focus.md](../../conventions/implementations/focus.md) を参照

---

## 関連

- [session.md](./session.md) — `Session` / `SessionState` の構造と役割分担
- [active-session.md](./active-session.md) — アクティブ Session の切替規約
- [ui-rules.md](./ui-rules.md) — Session 共通 UI 仕様
- [conventions/implementations/focus.md](../../conventions/implementations/focus.md) — 本契約の実装規約
- [ADR 0012](../../decisions/0012-keyboard-focus-dual-path.md) — キーボードフォーカスの 2 経路管理 (本契約の元)
- [ADR 0013](../../decisions/0013-session-as-first-class-object.md) — Session を first-class object に
- [ADR 0018](../../decisions/0018-session-and-state-separation.md) — Session と SessionState の分離理由
- [ADR 0020](../../decisions/0020-session-focus-bridge.md) — フォーカス契約をブリッジヘルパに委譲する設計
