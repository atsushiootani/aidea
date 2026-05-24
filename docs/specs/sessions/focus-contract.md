---
title: Session フォーカス契約
description: Session 間の一貫性を担保するための不変条件と 3 つの契約 (C1 / C2 / C3)。AppKit 系 SessionState は SessionFocusBridge を介して履行、純 SwiftUI 系は isActive フラグで履行する
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
last_updated: 2026-04-21
---

# Session フォーカス契約

各 Session が AppKit (`firstResponder`) と SwiftUI (SwiftUI フォーカスバインド) の両方のフォーカス機構を併用しても **Session 間で矛盾が起きないこと** を担保するための契約。

本ファイルは **Session 間の一貫性** だけを対象とする。Session 内部の NSView 同士のフォーカス調整 (クリックによる firstResponder 奪取を SwiftUI フォーカスバインド に追従させる等) は別ファイルで追補する。

`Session` / `SessionState` の役割分担は [session.md](./session.md)、関連する設計判断は [ADR 0012](../../decisions/0012-keyboard-focus-dual-path.md) / [ADR 0013](../../decisions/0013-session-as-first-class-object.md) / [ADR 0018](../../decisions/0018-session-and-state-separation.md) / [ADR 0020](../../decisions/0020-session-focus-bridge.md) を参照。Session アクティブ化の意味論は [active-session.md](./active-session.md) を参照。

---

## 原則

1. **Session ルートビューは全て SwiftUI で統一する**
2. **Session 間のフォーカスルーティングは `SessionRegistry.activeSessionID` を起点とする**
3. **`Session` クラスは AppKit 知識を持たない**。`focusableView` プロパティも `makeFirstResponder` 呼び出しもしない
4. **フォーカス契約 (C1 / C2 / C3) は `SessionState` が履行する**
5. **AppKit 系 `SessionState`** は `SessionFocusBridge` ヘルパを 1 つ保持し、契約ロジックを bridge に委譲する
6. **純 SwiftUI 系 `SessionState`** は `isActive: Bool` フラグだけを持ち、SwiftUI の `.focused()` バインディングがフォーカス制御を担う
7. **`SessionFocusBridge` の `view` 参照の更新は View (NSViewRepresentable) が責任を持つ** (`makeNSView` 内で `bridge.setView(_:)` を呼ぶ)

この分担により、AppKit 知識は **`SessionFocusBridge` の中だけに閉じる**。Window・`SessionRegistry`・`Session` クラス・他 Session・純 SwiftUI 系 SessionState は AppKit Window API を直接操作しない。

---

## 不変条件

任意の時点で以下が成立していなければならない:

- **I1 (排他性)**: アクティブ扱いの Session は高々 1 つである
- **I2 (整合性)**: `window.firstResponder` が任意の NSView を指しているとき、その NSView は **アクティブ Session の View 階層配下** に属する (= `isDescendant(of:)` が真となる Session がアクティブ Session と一致する)
- **I3 (空許容)**: `window.firstResponder` が Window 自身 (= どの Session にも属さない) であることは許される。この状態は「アクティブ Session は存在するが、その内部で firstResponder を持っていない」状況を意味する

I2 が破れると「アクティブ Session は B のはずなのに、キー入力が Session A に届く」という矛盾が起きる。本契約はこれを防ぐために存在する。

---

## SessionFocusBridge

AppKit 系 `SessionState` のフォーカス制御を担う **非永続ヘルパオブジェクト**。各 AppKit 系 SessionState が 1 つだけインスタンスを保持する。

### 責務

- 内包する NSView 参照 (`view: NSView?`) と `pendingActivation: Bool` フラグを保持
- View 側 (NSViewRepresentable) からの `setView(_:)` 呼び出しで参照を更新する
- `activate()` / `deactivate()` / `releaseIfOurs()` の 3 メソッドで契約 C1 / C2 / C3 を履行する
- AppKit Window API (`window.makeFirstResponder` 等) はこの中だけに閉じる

### API

`SessionFocusBridge` は以下の操作を提供する:

| メソッド | 呼び出し元 | 動作 |
|---|---|---|
| `setView(_:)` | View 側 (NSViewRepresentable の makeNSView) | 内包する NSView 参照を更新する。nil も有効 |
| `activate()` | SessionState の didBecomeActive (契約 C1) | view が non-nil なら makeFirstResponder を呼ぶ。nil なら pending を立てて待機 |
| `deactivate()` | SessionState の didResignActive (契約 C2) | 自分配下の NSView が firstResponder のときだけ解放する |
| `releaseIfOurs()` | View 側の onDisappear (契約 C3) | deactivate と同じ判定で firstResponder を解放する |

### 内部挙動の要点

- `setView(_:)` で値が更新され、かつ `pendingActivation == true` かつ新しい view が non-nil なら、その場で `makeFirstResponder` を発火して pending を解消する
- `activate()` は `view` が nil なら `pendingActivation = true` を立てるだけで何もしない (後の `setView` で解消される)
- `deactivate()` / `releaseIfOurs()` は **`window.firstResponder` が `view` 自身またはその子孫の場合だけ** `makeFirstResponder(nil)` を呼ぶ。それ以外は何もしない
- `view` を弱参照 (`weak`) で保持し、NSView の所有は SessionState 側 (lazy property) に任せる

---

## 契約

### 契約 C1: アクティブ化時の反映

`SessionRegistry` がアクティブ Session を切り替えた瞬間に、**自 Session 配下の NSView を firstResponder にする** (純 SwiftUI 系 Session は SwiftUI の `.focused()` パスに委譲)。

| Session 種別 | 履行方法 |
|---|---|
| **AppKit 系** | `SessionState.didBecomeActive` から `focusBridge.activate()` を呼ぶ。`focusBridge` は `view` が non-nil なら `makeFirstResponder(view)` を、nil なら `pendingActivation = true` を実行 |
| **純 SwiftUI 系** | `SessionState.didBecomeActive` で `isActive = true` を代入。SwiftUI の `.focused($isActive)` が SwiftUI 内部 NSView を firstResponder にする |

### 契約 C2: 非アクティブ化時の解除

`SessionRegistry` が自 Session を非アクティブ化したとき、**自 Session が握っている firstResponder を解放する**。

| Session 種別 | 履行方法 |
|---|---|
| **AppKit 系** | `SessionState.didResignActive` から `focusBridge.deactivate()` を呼ぶ。`focusBridge` は自分配下の NSView が firstResponder の場合のみ `makeFirstResponder(nil)` を実行 |
| **純 SwiftUI 系** | `SessionState.didResignActive` で `isActive = false` を代入。SwiftUI の `.focused($isActive)` が自動で内部 NSView を responder から外す |

**判定は必須 (AppKit 系)**: 無条件に `makeFirstResponder(nil)` を呼んではならない。次にアクティブ化された Session が契約 C1 で既に firstResponder を取得済みの場合があり、その場合は奪い返してはならない。`SessionFocusBridge.deactivate()` の内部判定 (自分配下チェック) でこれを保証する。

### 契約 C3: View 破棄時の解除

Session ルートビューがビュー階層から消える (`onDisappear` 相当のタイミング) とき、**契約 C2 と同じ解放処理を実行する**。

| Session 種別 | 履行方法 |
|---|---|
| **AppKit 系** | View ルートに `.sessionFocusCleanup(state)` modifier を 1 行付与。modifier の `onDisappear` で `state.focusBridge.releaseIfOurs()` を呼ぶ |
| **純 SwiftUI 系** | 何もしない (SwiftUI が `.focused()` バインドの自動クリーンアップで対応) |

`.sessionFocusCleanup` View modifier を使い、AppKit 系 SessionState の `focusBridge.releaseIfOurs()` を `onDisappear` 時に呼ぶ。AppKit 系 SessionState は `FocusBridgeOwner` プロトコルに準拠することで、modifier 側で型判定して bridge を呼べる。

---

## focusableView (NSView) の更新責任

AppKit 系 Session で、`SessionFocusBridge` が保持する `view` 参照の **更新は View 層 (NSViewRepresentable)** が責任を持つ。SessionState は NSView の所有・生成 (`cached` プロパティ等) のみを担当する。

### 基本ルール

- **更新する場所**: `NSViewRepresentable.makeNSView(context:)` 内で 1 回だけ
- **更新する手段**: `state.focusBridge.setView(view)` を呼ぶ
- **代入時のラップ**: `DispatchQueue.main.async { state.focusBridge.setView(view) }` で SwiftUI の update cycle と分離する
- **`updateNSView` での再代入は不要**: NSView インスタンスは Representable のライフサイクル中ずっと同じ
- **`dismantleNSView` では何もしない**: NSView は SessionState 所有で生き続けるため、参照を残しても dangling にならない。Session ルートの `.sessionFocusCleanup` (契約 C3) が firstResponder の解放だけ責任を持つ

### 実装パターン

`NSViewRepresentable.makeNSView` で一度だけ `state.focusBridge.setView(view)` を呼ぶ。SwiftUI の update cycle と分離するため `DispatchQueue.main.async` でラップする。`updateNSView` での再代入は不要 (NSView インスタンスはライフサイクル中ずっと同じ)。

### 子 View 切替時の更新

Session 内部で複数の子 View 種別を切り替える場合 (Preview のコンテンツ切替等)、**新しい子 View が `setView` を呼ぶ責任を持つ**:

- NSView 系子 View → `state.focusBridge.setView(nsView)` (新しい NSView を登録)
- 純 SwiftUI 系子 View → `state.focusBridge.setView(nil)` (登録を外し、SwiftUI の `.focused()` パスに委譲)

`setView(nil)` を受けた bridge は、その状態で `activate()` が呼ばれても何もしない (pending 状態として待機するが解消される機会がない)。この場合は SwiftUI の `.focused()` 経由でフォーカスが取られることを期待する。

### 複数 NSView を持つ Session

1 つの Session が複数の内部 NSView を持つ場合 (例: Git Diff の OutlineView + WKWebView)、**View 側がどれを `setView` するか選択する**。Session 間契約の観点ではどれを選んでも構わないが、**選択は 1 つに限る**こと (`SessionFocusBridge.view` は単一参照)。複数 NSView 間の内部フォーカス調整は本契約の範囲外。

---

## 各 SessionState の責務

| SessionState | 種別 | フォーカス契約のための実装 |
|---|---|---|
| AppKit 系 (Terminal / Claude / Web / Filer / Git / GitDiff / Preview の NSView 系コンテンツ) | `let focusBridge = SessionFocusBridge()` を持つ。`didBecomeActive` で `focusBridge.activate()`、`didResignActive` で `focusBridge.deactivate()` を呼ぶ | `FocusBridgeOwner` に準拠 |
| 純 SwiftUI 系 (Kit / Preview の純 SwiftUI コンテンツ) | `var isActive: Bool = false` を持つ。`didBecomeActive` で `isActive = true`、`didResignActive` で `isActive = false` を実行 | `FocusBridgeOwner` に準拠しない |

各 SessionState はこれら以外のフォーカス制御コードを持たない。Tool 固有のドメイン処理 (リロード / sendMessage 等) のみが固有の役割となる。

---

## 契約履行による不変条件の保証

- **I1** は `SessionRegistry.activeSessionID` が単一値であることによって自動的に保証される
- **I2** は 契約 C1 (アクティブ化時にアクティブ Session 配下へ移す) と 契約 C2 (非アクティブ化時に他 Session 配下へ残さない) の組み合わせで保証される
- **I3** は 契約 C2・C3 が生み出す「Window 自身が firstResponder」状態を明示的に許容することで破れを防ぐ

### 状態遷移の並行性に関する注意

`SessionRegistry.setActiveTab` は `oldSession.deactivate()` → `newSession.activate()` の順で同期的に呼ぶため、契約 C2 → C1 の順序は保証される。ただし C2 の判定条件 (「自分配下の NSView が firstResponder である場合のみ」) は将来的に並行発火が起きるケース (例: 複数 Window 間の切替) に備えて必須とする:

- 順序が `A 非アクティブ → B アクティブ` のケース: A が firstResponder を nil に落とす → B が自 NSView を firstResponder に設定。最終状態は正しい
- 順序が `B アクティブ → A 非アクティブ` のケース (将来的): B が自 NSView を firstResponder に設定 → A は「firstResponder が自分配下ではない」と判定して何もしない。最終状態も正しい

どちらの順序でも最終的な `window.firstResponder` は B 配下の NSView に収束する。

純 SwiftUI 系 Session が絡む遷移も同様に、SwiftUI フォーカスバインド の値変化を SwiftUI が処理する際に「現在の firstResponder が自分の SwiftUI NSView か」を内部判定するため、他 Session の firstResponder を奪うことはない。

---

## 責務の境界

| レイヤ | 契約の観点での責務 | 知らなくてよいこと |
|---|---|---|
| `SessionRegistry` | `Session.activate()` / `deactivate()` を切替時に呼ぶ | NSView、`firstResponder`、SessionState の種別 |
| `Session` クラス | `state.didBecomeActive` / `didResignActive` への委譲のみ | NSView、`firstResponder`、Tool 固有処理 |
| **AppKit 系 SessionState** | `focusBridge.activate()` / `deactivate()` を呼ぶ | 他 Session、AppKit Window API の詳細 (bridge に閉じる) |
| **純 SwiftUI 系 SessionState** | `isActive` フラグを更新する | NSView、firstResponder、AppKit |
| **`SessionFocusBridge`** | C1 / C2 / C3 の AppKit 側ロジックを実装 | Tool 固有処理、SessionState の他フィールド |
| Session ルート View | `.sessionFocusCleanup(state)` modifier を 1 行付ける、内部 NSViewRepresentable に state を渡す | 他 Session の存在 |
| NSViewRepresentable | `state.focusBridge.setView(_:)` を `makeNSView` 内で呼ぶ | 他 Session、契約 C1 / C2 / C3 |
| 内部 NSView | AppKit のネイティブな振る舞いに従う | SwiftUI フォーカスバインド、他 Session |

`SessionFocusBridge` がフォーカス契約 (C1 / C2) の **責任主体** となり、AppKit 知識をその中に閉じ込める。`Session` クラスと純 SwiftUI 系 SessionState は AppKit を一切知らなくてよい構造。

---

## 本仕様の範囲外

以下は本ファイルで扱わない。別途追補する。

- **Session 内部の NSView 同士のフォーカス調整** — 1 つの Session が複数の NSView を内部に持ち、それらの間で firstResponder が移動する場合の振る舞い
- **ユーザー操作由来の firstResponder 変化を SwiftUI フォーカスバインド / `isActive` に追従させる方法** — 内部 NSView がクリック等で firstResponder を奪ったときに Session 側の状態を更新する経路 (`becomeFirstResponder` フック / `NSWindow.firstResponder` の KVO 等)
- **サブクラス不可能な NSView (WKWebView 等) への対応手段**
- **`Session.activate()` / `SessionFocusBridge` の具体的な実装コード** — 本契約は仕様であり、実装は `Aidea/Tools/Session.swift` および `Aidea/Tools/SessionFocusBridge.swift` を参照

これらは契約 C1 / C2 / C3 が前提とする「Session ルートが View modifier を付けており、bridge に NSView 参照が登録されている」状態を作るための手段であり、本契約とは別レイヤの関心事として切り分ける。

---

## 関連

- [session.md](./session.md) — `Session` / `SessionState` の構造と役割分担
- [active-session.md](./active-session.md) — アクティブ Session の切替規約
- [ui-rules.md](./ui-rules.md) — Session 共通 UI 仕様
- [ADR 0012](../../decisions/0012-keyboard-focus-dual-path.md) — キーボードフォーカスの 2 経路管理 (本契約の元)
- [ADR 0013](../../decisions/0013-session-as-first-class-object.md) — Session を first-class object に
- [ADR 0018](../../decisions/0018-session-and-state-separation.md) — Session と SessionState の分離理由
- [ADR 0020](../../decisions/0020-session-focus-bridge.md) — フォーカス契約を SessionState + SessionFocusBridge に委譲する設計
