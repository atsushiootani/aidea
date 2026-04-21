---
title: "0018: Session と SessionState を分離して保持する"
description: Session (汎用クラス) と SessionState (Tool 固有 protocol 実装) を統合せず分離する判断と、4 つの分離理由
status: 採用
derived_from:
  - docs/decisions/0013-session-as-first-class-object.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-21
---

# 0018: Session と SessionState を分離して保持する

**日付**: 2026-04-21

## 背景

ADR 0013 で Session を first-class object 化したことで、コード上は以下の 2 階層が並立している:

- **`Session`** (汎用 `@Observable` クラス) — `id`, `focusableView`, `state` への参照、ライフサイクルメソッドを持つ
- **`SessionState`** (protocol) — Tool ごとに 1 つの具体実装クラスが存在し、Tool 固有のドメイン状態と振る舞いを保持

`Session` は `id`, `focusableView`, `state` 参照しか持たない薄い入れ物に見えるため、「`SessionState` に `id` を持たせて統合すれば `Session` クラスは不要では」という疑問が起きやすい。技術的には統合可能であるため、**分離を維持する根拠**を明文化する必要がある。

各クラスの定義と役割の詳細は [docs/specs/sessions/session.md](../specs/sessions/session.md) を参照。

## 判断

**`Session` と `SessionState` の分離を維持する**。`SessionState` への統合 (id を持たせて `Session` クラスを廃止) は採用しない。

## 理由

### ① protocol は stored property を共通化できない

複数の Tool に共通する状態 (例: `pendingActivation` のようなフォーカス契約用フラグ) を 1 箇所に置きたい場合、protocol extension では computed property しか書けないため stored property を共通化できない。

```swift
// 不可: protocol extension では stored property を持てない
extension SessionState {
    var pendingActivation: Bool { ... }   // ← computed しか書けない
}
```

統合した場合、各 SessionState 実装が同じ stored property を自前で持つ重複構造になる。`Session` クラスを挟むことで、共通の stored property + 共通ロジックを 1 箇所に集約できる。

この性質は [docs/specs/sessions/focus-contract.md](../specs/sessions/focus-contract.md) の契約 C1 / C2 を `Session` クラスに集約する設計と直結している。

### ② 永続化境界が型で表現される

| クラス | 永続化対象 | 例 |
|---|---|---|
| **SessionState** | ✅ (Tool 固有のドメイン状態) | `url`, `treeNodes`, `excludeRules` |
| **Session** | ❌ (`id` 以外は永続化しない UI 状態) | `focusableView` (NSView は Codable 不可) |

統合すると永続化対象とそうでないプロパティが同じクラスに同居し、Codable / Snapshot 対応の境界が曖昧になる。分離しておけば「Snapshot は SessionState のフィールドだけ」というルールでクリアに切れる。

### ③ 型消去 (`any SessionState`) を呼び出し側に漏らさない

`SessionState` は protocol のため、外部から扱うときに `any SessionState` の型消去が常について回る。`Session` は具象クラスなので、UI 層は `let session: Session` で安定参照でき、必要なときだけ `state` をキャストする 2 段階アクセスが可能になる。

```swift
struct TerminalSessionView: View {
    let session: Session                                       // 具象型で受ける
    var body: some View {
        let state = session.state as! TerminalSessionState     // 必要時だけキャスト
        ...
    }
}
```

### ④ ライフサイクル制御の責任主体が明確

`activate()` / `deactivate()` を呼び出す責任が `SessionRegistry` にあり、その呼び出し先が `Session` クラスに集約される。`Session.activate()` の中でフォーカス契約 (C1) を履行してから `state.didBecomeActive` に委譲する 2 段構造により、Tool 固有の処理を書く各 SessionState が共通契約を素通りすることを防ぐ。

統合した場合、`state.activate()` を直接呼ぶことになり、共通契約を protocol の default 実装に置く必要が出る → 理由 ① に戻る。

## トレードオフ

上記 4 つはいずれも「分けないと不可能」ではなく「分けた方が綺麗」レベルの判断であり、技術的には associated object や Snapshot 専用 struct 等で回避可能。ただし以下の前提が崩れない限り分離を維持する:

- フォーカス契約 ([focus-contract.md](../specs/sessions/focus-contract.md)) のような **全 Session 共通の振る舞い**を 1 箇所に集約したい
- 永続化対象とそうでないものを **明示的に区別**したい
- Tool ごとの SessionState 実装は **独立して進化させたい** (Tool 固有処理だけに集中させる)

逆に `Session` クラスに UI 関心事 (NSWindow / makeFirstResponder 等の AppKit 知識) を増やしすぎると、薄い入れ物のはずが肥大化するため、追加するロジックは「全 Session 共通の振る舞いか」を都度判断する。

## 関連

- [ADR 0013](./0013-session-as-first-class-object.md) — Session を first-class object にした上位判断 (本 ADR の前提)
- [docs/specs/sessions/session.md](../specs/sessions/session.md) — 現在の `Session` / `SessionState` 構造の仕様
- [docs/specs/sessions/focus-contract.md](../specs/sessions/focus-contract.md) — 分離前提で成立するフォーカス契約
