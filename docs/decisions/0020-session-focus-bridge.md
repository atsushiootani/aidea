---
title: "0020: フォーカス契約を SessionState + SessionFocusBridge に委譲する"
description: Session クラスから focusableView と AppKit 知識を取り除き、フォーカス契約 (C1/C2/C3) を各 SessionState が SessionFocusBridge ヘルパ経由で履行する設計
status: 採用
derived_from:
  - docs/decisions/0012-keyboard-focus-dual-path.md
  - docs/decisions/0013-session-as-first-class-object.md
  - docs/decisions/0018-session-and-state-separation.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-21
---

# 0020: フォーカス契約を SessionState + SessionFocusBridge に委譲する

**日付**: 2026-04-21

## 背景

[ADR 0013](./0013-session-as-first-class-object.md) で `focusableView: NSView?` を `SessionState` から `Session` クラスに移し、フォーカス契約 ([focus-contract.md](../specs/sessions/focus-contract.md) の C1 / C2 / C3) を `Session.activate()` / `deactivate()` に集約する案を採った。この設計は ADR 0018 で確認した「全 Session 共通の振る舞いを 1 箇所に集約する」目的に沿っていたが、運用上 2 つの問題が見えてきた。

### 問題 1: Session クラスが AppKit 知識を持つ

`Session.focusableView: NSView?` および `activate()` 内の `window.makeFirstResponder(view)` 呼び出しにより、`Session` クラス自身が NSView と AppKit Window API を直接扱う。`Session` を「id と state を持つだけの薄い入れ物」とした ADR 0018 の意図に反し、責務が肥大化する方向にある。

### 問題 2: 「nil = 純 SwiftUI Session」の暗黙判定

`focusableView == nil` をもって「純 SwiftUI Session」と暗黙的に扱う設計は、型では区別できない。さらに Session 内部の子 View 切替 (例: Preview のコンテンツ種別切替) で NSView 系 → 純 SwiftUI 系へ遷移する場合、子 View 側が明示的に `session.focusableView = nil` を代入する必要があり、書き忘れリスクが生じる。

### 問題 3: 「Session 集約」と「Session の薄さ」のジレンマ

ADR 0018 では「全 Session 共通の振る舞いを 1 箇所に集約したい場合に Session クラスが有効」としたが、実際にはその「1 箇所」は **必ずしも `Session` クラス本体である必要はない**。共通ロジックを集約するヘルパオブジェクトを各 SessionState が持つ形でも、重複は避けられる。

## 判断

**フォーカス契約 (C1 / C2 / C3) の責務を `Session` クラスから `SessionState` に移し、共通ロジックは `SessionFocusBridge` というヘルパオブジェクトに集約する。`Session` クラスは `focusableView` プロパティと AppKit 知識を一切持たない。**

### 概念

| 種別 | フォーカス制御の手段 |
|---|---|
| **AppKit 系 SessionState** (Terminal / Claude / Web / Filer / Preview の NSView 系コンテンツ / Git / GitDiff) | `SessionFocusBridge` インスタンスを 1 つ保持し、`didBecomeActive` / `didResignActive` で `activate()` / `deactivate()` を呼ぶ |
| **純 SwiftUI 系 SessionState** (Kit / Preview の純 SwiftUI コンテンツ) | `isActive: Bool` フラグを更新するだけ。SwiftUI の `.focused($isActive)` バインディングが内部 NSView の firstResponder 出し入れを自動で行う |

### `SessionFocusBridge` の責務

- 内包する NSView 参照と `pendingActivation` フラグを保持
- View 側 (NSViewRepresentable) からの `setView(_:)` 呼び出しで参照を更新し、pending 解消を行う
- `activate()` / `deactivate()` / `releaseIfOurs()` の 3 メソッドで C1 / C2 / C3 を履行
- AppKit Window API (`makeFirstResponder` 等) はこの中だけに閉じる

詳細仕様は [focus-contract.md](../specs/sessions/focus-contract.md) を参照。

## 理由

### ① Session クラスが真に「id と state を持つ薄い入れ物」になる

`Session` から `focusableView` プロパティと AppKit API 呼び出しが消える。`Session` の役割は `SessionRegistry` から `activate()` / `deactivate()` を受けて `state` に委譲することだけになる。ADR 0018 で確認した分離理由 (特に「Session への肥大化を避ける」) と整合する。

### ② 「nil = 純 SwiftUI Session」の暗黙判定が消える

純 SwiftUI 系 SessionState は `SessionFocusBridge` を持たない。これにより「フォーカス制御の手段」が **型 (state の構造)** で表現される。`focusableView == nil` のような暗黙判定は不要になる。

### ③ 子 View 切替時の責務が単純化する

Preview のような複合 Session で子 View が NSView 系 → 純 SwiftUI 系に切り替わる場合も、子 View が `state.focusBridge.setView(nil)` を呼ぶか、あるいは Preview の SessionState が新しい子 View 種別に応じて bridge を持つかを切り替えるだけで完結する。`Session` クラスのプロパティを書き換える必要はない。

### ④ ADR 0018 の理由 ① (protocol stored property 制約) と整合する

ADR 0018 では「protocol extension では stored property を共通化できないため、共通の `pendingActivation` を Session クラスに置く」と論じた。`SessionFocusBridge` ヘルパを各 SessionState のフィールドとして持たせれば、stored property の共通化問題は **クラス継承ではなくオブジェクト合成** で解決できる。Session を経由する必要は本質的にはなかった。

### ⑤ テストしやすい

`SessionFocusBridge` は単独で `view` / `pendingActivation` / `activate()` / `deactivate()` の単体テストが書ける。Session クラスや SessionState 全体をセットアップする必要がない。

## トレードオフ

- **C1 / C2 の実装場所が分散**: `Session.activate()` 内の 1 箇所から、各 AppKit 系 SessionState の `didBecomeActive` 内 (`focusBridge.activate()` の 1 行呼び出し) へ。ただし呼び出し自体は単純なため重複コストは小さい
- **書き忘れリスク**: 各 AppKit 系 SessionState が `focusBridge.activate()` / `deactivate()` を `didBecomeActive` / `didResignActive` で呼ぶのを忘れると契約違反が起きる。ただし `SessionFocusBridge` を持つ State は全て同じパターンなので grep / lint で検出可能
- **ヘルパインスタンスの管理が増える**: 各 AppKit 系 state が `SessionFocusBridge` を 1 つ持つ。リソース的には軽微

## 0013 との関係

ADR 0013 は「Session を first-class object にして Window 全体で管理する」「focusableView の保持先を SessionState から Session に移す」の 2 つを提案していた。本 ADR は **前者は維持、後者を撤回** する位置づけ。

| 0013 の提案 | 本 ADR での扱い |
|---|---|
| Session を first-class object に | ✅ 維持 |
| `SessionRegistry.sessions: [Session]` で公開配列管理 | ✅ 維持 |
| `focusableView: NSView?` を Session に持たせる | ❌ 撤回 — `SessionFocusBridge` として各 SessionState に戻す |
| 「focusableView の有無」でフォーカス方式を分岐 | ❌ 撤回 — SessionState の型で分岐 |

ADR 0013 の `focusableView` 配置に関する判断のみが置換され、Session を first-class object として保持する核心の判断は維持される。

## 関連

- [ADR 0012](./0012-keyboard-focus-dual-path.md) — 2 経路フォーカス管理 (本契約の元)
- [ADR 0013](./0013-session-as-first-class-object.md) — Session を first-class object に (本 ADR で `focusableView` 配置のみ撤回)
- [ADR 0018](./0018-session-and-state-separation.md) — Session と SessionState の分離理由 (本 ADR で強化される)
- [docs/specs/sessions/session.md](../specs/sessions/session.md) — 現在の構造仕様
- [docs/specs/sessions/focus-contract.md](../specs/sessions/focus-contract.md) — フォーカス契約の現行仕様
