---
title: フォーカス契約の実装規約
description: フォーカス契約 (C1/C2/C3) を履行する実装規約。SessionFocusBridge / setView の責任 / クリックモニタの登録と解放
derived_from:
  - docs/specs/sessions/focus-contract.md
  - docs/decisions/0012-keyboard-focus-dual-path.md
  - docs/decisions/0020-session-focus-bridge.md
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# フォーカス契約の実装規約

[フォーカス契約 (C1 / C2 / C3)](../../specs/sessions/focus-contract.md) をコードで履行するときに従う実装規約。
**要件・不変条件は spec 側が SSoT** で、本ファイルは「どう書くか」だけを扱う。
実装に至った判断の経緯は [ADR 0012](../../decisions/0012-keyboard-focus-dual-path.md) / [ADR 0020](../../decisions/0020-session-focus-bridge.md) を参照。

## 原則

1. **Session ルートビューは全て SwiftUI で統一する**
2. **Session 間のフォーカスルーティングは `SessionRegistry.activeSessionID` を起点とする**
3. **`Session` クラスは AppKit 知識を持たない**。`focusableView` プロパティも `makeFirstResponder` 呼び出しもしない
4. **フォーカス契約 (C1 / C2 / C3) は `SessionState` が履行する**
5. **AppKit 系 `SessionState`** は `SessionFocusBridge` ヘルパを 1 つ保持し、契約ロジックを bridge に委譲する
6. **純 SwiftUI 系 `SessionState`** は `isActive: Bool` フラグだけを持ち、SwiftUI の `.focused()` バインディングがフォーカス制御を担う
7. **`SessionFocusBridge` の `view` 参照の更新は View (NSViewRepresentable) が責任を持つ** (`makeNSView` 内で `bridge.setView(_:)` を呼ぶ)

この分担により、AppKit 知識は **`SessionFocusBridge` の中だけに閉じる**。Window・`SessionRegistry`・`Session` クラス・他 Session・純 SwiftUI 系 SessionState は AppKit Window API を直接操作しない。

不変条件 I2 (spec 側) は実装上「`window.firstResponder` が指す NSView は、アクティブ Session の View 階層配下 (`isDescendant(of:)` が真) に属する」と等価。I3 の「どの View もキー入力を受けていない」状態は「`window.firstResponder` が Window 自身」に対応する。

## SessionFocusBridge

AppKit 系 `SessionState` のフォーカス制御を担う **非永続ヘルパオブジェクト**。各 AppKit 系 SessionState が 1 つだけインスタンスを保持する。

### 責務

- 内包する NSView 参照と `pendingActivation` フラグを保持
- View 側から View 参照の更新を受け取り、内部状態を同期する
- activate / deactivate / releaseIfOurs の 3 操作で契約 C1 / C2 / C3 を履行する
- AppKit Window フォーカス API (`window.makeFirstResponder` 等) はこの中だけに閉じる

### 操作一覧

| 操作 | 呼び出し元 | 動作 |
|---|---|---|
| **setView** | View 側 (AppKit ブリッジの初期化時) | 内包する NSView 参照を更新する。nil も有効 |
| **activate** | SessionState のアクティブ化 (契約 C1) | view が non-nil なら makeFirstResponder を呼ぶ。nil なら pending を立てて待機 |
| **deactivate** | SessionState の非アクティブ化 (契約 C2) | 自分配下の NSView が firstResponder のときだけ解放する |
| **releaseIfOurs** | View 側の消滅時 (契約 C3) | deactivate と同じ判定で firstResponder を解放する |

### 内部挙動の要点

- View 参照が更新され、かつ `pendingActivation` が true かつ新しい view が non-nil なら、その場で `makeFirstResponder` を発火して pending を解消する
- activate は `view` が nil なら `pendingActivation = true` を立てるだけで何もしない (後の View 参照更新で解消される)
- deactivate / releaseIfOurs は **`window.firstResponder` が `view` 自身またはその子孫の場合だけ** `makeFirstResponder(nil)` を呼ぶ。それ以外は何もしない
- `view` を弱参照で保持し、NSView の所有は SessionState 側 (lazy property) に任せる

## 契約 C1 / C2 / C3 の履行方法

### C1: アクティブ化時の反映

| Session 種別 | 履行方法 |
|---|---|
| **AppKit 系** | `SessionState.didBecomeActive` から `focusBridge.activate()` を呼ぶ。`focusBridge` は `view` が non-nil なら `makeFirstResponder(view)` を、nil なら `pendingActivation = true` を実行 |
| **純 SwiftUI 系** | `SessionState.didBecomeActive` で `isActive = true` を代入。SwiftUI の `.focused($isActive)` が SwiftUI 内部 NSView を firstResponder にする |

### C2: 非アクティブ化時の解除

| Session 種別 | 履行方法 |
|---|---|
| **AppKit 系** | `SessionState.didResignActive` から `focusBridge.deactivate()` を呼ぶ。`focusBridge` は自分配下の NSView が firstResponder の場合のみ `makeFirstResponder(nil)` を実行 |
| **純 SwiftUI 系** | `SessionState.didResignActive` で `isActive = false` を代入。SwiftUI の `.focused($isActive)` が自動で内部 NSView を responder から外す |

**判定は必須 (AppKit 系)**: 無条件に `makeFirstResponder(nil)` を呼んではならない。次にアクティブ化された Session が契約 C1 で既に firstResponder を取得済みの場合があり、その場合は奪い返してはならない。`SessionFocusBridge.deactivate()` の内部判定 (自分配下チェック) でこれを保証する。

### C3: View 破棄時の解除

| Session 種別 | 履行方法 |
|---|---|
| **AppKit 系** | View ルートに `.sessionFocusCleanup(state)` modifier を 1 行付与。modifier の `onDisappear` で `state.focusBridge.releaseIfOurs()` を呼ぶ |
| **純 SwiftUI 系** | 何もしない (SwiftUI が `.focused()` バインドの自動クリーンアップで対応) |

AppKit 系 SessionState は `FocusBridgeOwner` プロトコルに準拠することで、modifier 側で型判定して bridge を呼べる。

## focusableView (NSView) の更新責任

AppKit 系 Session で、`SessionFocusBridge` が保持する `view` 参照の **更新は View 層 (NSViewRepresentable)** が責任を持つ。SessionState は NSView の所有・生成 (`cached` プロパティ等) のみを担当する。

### 基本ルール

- **更新する場所**: `NSViewRepresentable.makeNSView(context:)` 内で 1 回だけ
- **更新する手段**: `state.focusBridge.setView(view)` を呼ぶ
- **代入時のラップ**: `DispatchQueue.main.async { state.focusBridge.setView(view) }` で SwiftUI の update cycle と分離する
- **`updateNSView` での再代入は不要**: NSView インスタンスは Representable のライフサイクル中ずっと同じ
- **`dismantleNSView` では何もしない**: NSView は SessionState 所有で生き続けるため、参照を残しても dangling にならない。Session ルートの `.sessionFocusCleanup` (契約 C3) が firstResponder の解放だけ責任を持つ

### 子 View 切替時の更新

Session 内部で複数の子 View 種別を切り替える場合 (Preview のコンテンツ切替等)、**新しい子 View が `setView` を呼ぶ責任を持つ**:

- NSView 系子 View → `state.focusBridge.setView(nsView)` (新しい NSView を登録)
- 純 SwiftUI 系子 View → `state.focusBridge.setView(nil)` (登録を外し、SwiftUI の `.focused()` パスに委譲)

`setView(nil)` を受けた bridge は、その状態で `activate()` が呼ばれても何もしない (pending 状態として待機するが解消される機会がない)。この場合は SwiftUI の `.focused()` 経由でフォーカスが取られることを期待する。

### 複数 NSView を持つ Session

1 つの Session が複数の内部 NSView を持つ場合 (例: Git Diff の OutlineView + WKWebView)、**View 側がどれを `setView` するか選択する**。Session 間契約の観点ではどれを選んでも構わないが、**選択は 1 つに限る**こと (`SessionFocusBridge.view` は単一参照)。複数 NSView 間の内部フォーカス調整は本契約の範囲外。

## 各 SessionState の責務

| SessionState | 種別 | フォーカス契約のための実装 |
|---|---|---|
| AppKit 系 (Terminal / Claude / Web / Filer / Git / GitDiff / Preview の NSView 系コンテンツ) | `let focusBridge = SessionFocusBridge()` を持つ。`didBecomeActive` で `focusBridge.activate()`、`didResignActive` で `focusBridge.deactivate()` を呼ぶ | `FocusBridgeOwner` に準拠 |
| 純 SwiftUI 系 (Kit / Preview の純 SwiftUI コンテンツ) | `var isActive: Bool = false` を持つ。`didBecomeActive` で `isActive = true`、`didResignActive` で `isActive = false` を実行 | `FocusBridgeOwner` に準拠しない |

各 SessionState はこれら以外のフォーカス制御コードを持たない。Tool 固有のドメイン処理 (リロード / sendMessage 等) のみが固有の役割となる。

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

## 状態遷移の並行性に関する注意

`SessionRegistry.setActiveTab` は `oldSession.deactivate()` → `newSession.activate()` の順で同期的に呼ぶため、契約 C2 → C1 の順序は保証される。ただし C2 の判定条件 (「自分配下の NSView が firstResponder である場合のみ」) は将来的に並行発火が起きるケース (例: 複数 Window 間の切替) に備えて必須とする:

- 順序が `A 非アクティブ → B アクティブ` のケース: A が firstResponder を nil に落とす → B が自 NSView を firstResponder に設定。最終状態は正しい
- 順序が `B アクティブ → A 非アクティブ` のケース (将来的): B が自 NSView を firstResponder に設定 → A は「firstResponder が自分配下ではない」と判定して何もしない。最終状態も正しい

どちらの順序でも最終的な `window.firstResponder` は B 配下の NSView に収束する。

純 SwiftUI 系 Session が絡む遷移も同様に、SwiftUI フォーカスバインドの値変化を SwiftUI が処理する際に「現在の firstResponder が自分の SwiftUI NSView か」を内部判定するため、他 Session の firstResponder を奪うことはない。

## サブクラス不可能な NSView のクリック検知 (クリックモニタ)

`WKWebView` や `SwiftTerm.TerminalView` は `mouseDown` をオーバーライドできない (non-open) ため、内部でクリックされても SwiftUI の `simultaneousGesture` に先んじて AppKit 側で握りつぶされ、Session がアクティブ化されないことがある。この問題を解決する手段が **クリックモニタ**。

### 仕組み

- Session (または Tool 固有の NSView) の生成時に `NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown)` を 1 つ登録する
- モニタのクロージャは `event.window?.contentView?.hitTest(event.locationInWindow)` で実際にクリックされた NSView を求め、`isDescendant(of:)` で対象の NSView 配下かどうかを判定する
- 配下であれば `SessionRegistry.activateSession(_:)` を呼んで契約 C1 の起点 (`setActiveTab`) を発火させる

### 登録箇所

| 登録元 | 対象 | 判定基準 |
|---|---|---|
| `SessionRegistry.createSession` | `FocusBridgeOwner` に準拠する全 AppKit 系 SessionState 共通 | `focusBridge.trackedView` 配下か |
| `WebSessionState.configureWebView` | 個々の `WKWebView` (通常生成・adopt 共通) | 生成した `WKWebView` 配下か |
| `TerminalSessionState.terminalView` / `ClaudeSessionState.terminalView` | 個々の `PersistentTerminalView` | 生成した `PersistentTerminalView` 配下か |

Tool 固有の登録 (2 段目・3 段目) は、`focusBridge.trackedView` が View 側の `makeNSView` 完了まで未設定な間 (= Session 生成直後で NSView がまだ無い状態) でも WKWebView/PersistentTerminalView 自体へのクリックを取りこぼさないための保険であり、`SessionRegistry` 側の共通モニタと役割が重複していても問題ない (どちらか一方が発火すれば `activateSession` は冪等)。

### ライフサイクル (issue #263: モニタ解放漏れ)

`addLocalMonitorForEvents` の戻り値 (モニタトークン) を破棄すると、`NSEvent.removeMonitor(_:)` を呼ぶ手段が失われ、**クロージャがプロセス終了までグローバルに残り続ける**。Session/Tab を閉じても解放されないため、タブの開閉を繰り返すほど「以後のあらゆる左クリックで評価される無効なクロージャ」が単調増加し、アプリ全体の操作感が徐々に重くなる。

これを避けるため、クリックモニタを登録する側は必ずトークンを保持し、対応するリソースの破棄時に `NSEvent.removeMonitor(_:)` を呼ぶ。

| 登録元 | トークンの保持先 | 解放タイミング |
|---|---|---|
| `SessionRegistry.createSession` | `SessionRegistry` が `SessionID` をキーに保持 | `destroySession(_:)` |
| `WebSessionState` / `TerminalSessionState` / `ClaudeSessionState` | 各 SessionState 自身のプロパティ | 自身の `deinit` |

## 関連

- [../specs/sessions/focus-contract.md](../../specs/sessions/focus-contract.md) — 要件・不変条件・契約の定義 (SSoT)
- [swift.md](../swift.md) — SwiftUI / AppKit の使い分けと閉じ込めルール
- [ADR 0012](../../decisions/0012-keyboard-focus-dual-path.md) — キーボードフォーカスの 2 経路管理
- [ADR 0020](../../decisions/0020-session-focus-bridge.md) — フォーカス契約を SessionState + SessionFocusBridge に委譲する判断
