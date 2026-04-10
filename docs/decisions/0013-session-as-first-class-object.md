# 0013: Session を first-class object にして Window レベルで管理する

**日付**: 2026-04-10
**状態**: 提案 (実装前の概念設計段階)

## 背景

### 既存構造の問題
Session の実体 (`SessionState`) は `SessionRegistry.states: [SessionID: any SessionState]` に
`@ObservationIgnored` な private dict として隠れている。外部から Session を直接参照するには
`peekState(for:)` を通す必要があり、型消去 (`any SessionState`) されているため利用側でキャストが必要。

また `focusableView` (キー入力を受け取るべき NSView) の管理が各 SessionState に分散しており、
Preview のようにコンテンツ種別で focusableView が動的に変わるケースで統一的な管理が困難だった。
ADR 0012 で導入した 2 経路フォーカス方式は概念的には正しかったが、Preview の実装が
SwiftUI/AppKit ハイブリッドだったため「外側の View 型で判断」する方式では対応しきれなかった。

### 概念の整理
Tab・Session・Tool の 3 つの概念は以下のように位置づけられる:

| 概念 | 所属先 | 役割 |
|---|---|---|
| **Tool** | 定義 (enum) | 機能の種別 (filer, terminal, web, kit, preview) |
| **Session** | Window 全体 | 1 つの実体。状態を持ち、ライフサイクルが Window レベルで管理される |
| **Tab** | Pane | ペイン内の表示スロット。Session への軽い参照 (SessionID) |

現状の `SessionRegistry.states` は「Session がどこに管理されているかが分かりにくい」という問題がある。
Tab の追加/削除と Session の生成/破棄は同時に起きるが、Session は Pane に属するのではなく
**Window 全体に属する**ものとして明示的に管理すべき。

## 提案

### Session を first-class object に

```swift
/// Session の実体。Window 全体で管理される。
@Observable
final class Session: Identifiable {
    let id: SessionID
    let state: any SessionState

    /// キー入力を受け取るべき NSView。
    /// 子ビュー (NSTextView, WKWebView 等) が動的に更新する。
    /// nil のときは SwiftUI の @FocusState パスが使われる (Kit 等)。
    var focusableView: NSView?
}
```

### SessionRegistry が Session の一覧を公開

```swift
@Observable
final class SessionRegistry {
    /// 全 Session の一覧 (Window 全体で一意)
    private(set) var sessions: [Session] = []

    /// 現在アクティブな Session の ID
    var activeSessionID: SessionID?

    /// ID で Session を検索
    func session(for id: SessionID) -> Session? {
        sessions.first { $0.id == id }
    }

    /// Session を生成して一覧に追加 (Tab 追加と同時に呼ばれる)
    func createSession(tool: Tool, instance: Int) -> Session { ... }

    /// Session を破棄して一覧から除去 (Tab クローズと同時に呼ばれる)
    func destroySession(_ id: SessionID) { ... }

    /// アクティブ Session の focusableView を First Responder にする
    func refocusActiveSession() { ... }
}
```

### Pane は Session への参照のみ保持

```swift
@Observable
final class Pane {
    var tabs: [SessionID]  // Session への軽い参照
    var activeIndex: Int
}
```

Pane は `SessionID` のリストだけ持ち、Session の状態やフォーカスには関与しない。

### focusableView の管理

ADR 0012 で定義した 2 経路 (AppKit: makeFirstResponder / SwiftUI: @FocusState) は維持するが、
**判断基準を「Tool 種別」から「Session.focusableView の有無」に変更**する。

| focusableView | フォーカス方式 | 例 |
|---|---|---|
| non-nil (NSView) | `window.makeFirstResponder(view)` | Filer, Terminal, Web, Preview (text/drawio) |
| nil | SwiftUI `@FocusState` | Kit, Preview (markdown view, image) |

`focusableView` は **SessionState ではなく Session に持たせる**。
理由: focusableView は「ツール固有の状態」ではなく「Session の表示状態」に関するメタデータであり、
SessionState (永続化対象) と分離すべき。

### 子ビューが focusableView を報告する仕組み

子ビュー (NSViewRepresentable 等) は Session の `focusableView` を直接更新する:

```
子ビュー (NSTextPreview, DrawioStaticView 等)
  │
  ├─ makeNSView() で NSView を生成
  │
  └─ session.focusableView = nsView  // 報告
```

純 SwiftUI コンテンツ (MarkdownPreview view モード, Image) は
`FocusCatcherView` を `.background()` として配置し、その NSView を
`session.focusableView` に報告する。これにより常に non-nil の NSView が
First Responder を引き受けて、前のタブへのキー入力流出を防ぐ。

### refocusActiveSession の動作

```
activeSessionID が変わった
  │
  ├─ session = registry.session(for: activeSessionID)
  │
  ├─ session.focusableView が non-nil?
  │    └─ YES → window.makeFirstResponder(session.focusableView)
  │    └─ NO  → SwiftUI @FocusState パスに委譲 (何もしない)
  │
  (Kit の場合: KitSessionView の onChange → isFocused = true)
```

## 変更範囲

### ファイル変更

| ファイル | 変更内容 |
|---|---|
| `Tools/Tool.swift` | `SessionState` から focusableView を除去。Session クラスを新規定義 |
| `Sessions/SessionRegistry.swift` | `states` dict → `sessions` 配列に移行。createSession/destroySession API 追加 |
| `Sessions/*/` 各 SessionState | focusableView プロパティを削除 (Session 側に移動) |
| `Views/Layout/PaneView.swift` | Tab の追加/削除時に registry.createSession/destroySession を呼ぶ |
| `Views/Layout/ContentView.swift` | refocusActiveSession は registry 経由 (変化なし) |
| `Views/Sessions/Preview/*` | `state.setFocusableView()` → `session.focusableView = ` に変更 |
| `Services/Workspace/WorkspaceSnapshotManager.swift` | `registry.sessions` を走査して永続化 |
| `docs/specs/glossary.md` | Session / Tab / focusableView の定義を更新 |
| `docs/specs/SPEC.md` | 概念モデルの図を更新 |

### 概念的な変更

| Before (ADR 0012) | After (本 ADR) |
|---|---|
| SessionState が focusableView を持つ | **Session** が focusableView を持つ |
| Tool 種別で AppKit/SwiftUI パスを分岐 | **focusableView の有無**で分岐 |
| states が private dict (外から見えない) | **sessions が公開配列** (全 Session 列挙可能) |
| Tab 削除時に state は states に残る | Tab 削除時に **destroySession で明示的に除去** |

## トレードオフ

- **リファクタ範囲が広い**: SessionRegistry の内部構造変更 + 全呼び出し元の修正
- **Session クラスの追加**: SessionID + SessionState + focusableView を束ねるため新しい型が増える
- 一方で **全体から Session を探索する操作が劇的に簡潔になる** (focusTool, 永続化, フォーカス管理)

## 関連 ADR

- [0012](./0012-keyboard-focus-dual-path.md) — 2 経路フォーカス方式 (本 ADR で進化)
- [0011](./0011-cmd-w-via-nsevent-monitor.md) — Cmd+W の NSEvent monitor

## 3 つのアクティブ概念

Session を first-class object にすることに加え、Active の概念を以下の 3 階層に整理する。

### 定義

| 概念 | スコープ | 変更トリガー | 保存対象 |
|---|---|---|---|
| **Active Pane** | Window 全体で 1 つ | `⌘[` / `⌘]` (ペイン間移動) | `activePaneID: UUID` |
| **Active Tab** | 各 Pane 内で 1 つ | `⌘⇧[` / `⌘⇧]` (タブ移動) / タブクリック | `Pane.activeIndex: Int` |
| **Active Session** | Window 全体で 1 つ | **計算値** (= Active Pane の Active Tab) | (保存不要、上 2 つから導出) |

### Active Session は計算値

```swift
var activeSessionID: SessionID? {
    activePane?.tabs[activePane.activeIndex]
}
```

Active Session は独立した stored property ではなく、**Active Pane + Active Tab から一意に導出される**。
これにより:
- 同期ズレが**構造的に不可能**
- ペイン移動だけで Active Session も自動的に変わる
- タブ移動だけで Active Session も自動的に変わる
- 「2 箇所を同時にセット」する必要がない (Single Source of Truth)

### 操作との対応

| 操作 | 変わる Active | 変わらない Active |
|---|---|---|
| `⌘[` / `⌘]` (ペイン移動) | Active Pane → Active Session (導出) | 各 Pane の Active Tab |
| `⌘⇧[` / `⌘⇧]` (タブ移動) | Active Tab → Active Session (導出) | Active Pane |
| タブクリック | Active Tab → Active Session (導出) | Active Pane (クリックしたペインが Active Pane でなければそちらも変わる) |
| `⌘1` (ツールフォーカス) | Active Pane + Active Tab → Active Session | - |

### キー入力の対象

Active Session = Active Pane の Active Tab のセッション = キー入力の対象。
refocusActiveSession は activeSessionID (computed) を読んで focusableView を First Responder にする。

### 永続化

```json
{
  "activePaneID": "uuid-of-active-pane",
  "layout": {
    "leaf": {
      "nodeID": "...",
      "paneID": "uuid-of-pane",
      "pane": { "tabs": [...], "activeIndex": 2 }
    }
  }
}
```

activePaneID + 各 Pane の activeIndex だけで 3 つの Active が完全に復元できる。
Pane の UUID を LayoutNodeSnapshot.leaf に保存する必要がある。

### activeHistory

activeSessionID は computed property のため、変化を直接 observe できない。
変化の検知は以下の方法で行う:
- `activePaneID` の didSet / `Pane.activeIndex` の didSet で
  前回の activeSessionID と比較し、変わっていれば activeHistory に追加

## Session ライフサイクルコールバック

Session がアクティブ/非アクティブになったタイミングで、各 Session が自身に必要な処理を実行する。
キー受付開始 (First Responder / FocusState) はその処理の 1 つ。

### SessionState プロトコルにライフサイクルメソッドを追加

```swift
protocol SessionState: AnyObject {
    /// このセッションがアクティブになったとき呼ばれる。
    /// キー受付開始処理 (makeFirstResponder / FocusState 等) もここで行う。
    func didBecomeActive(session: Session)

    /// このセッションが非アクティブになったとき呼ばれる (任意)。
    func didResignActive(session: Session)
}
```

### 各 SessionState の実装

| SessionState | didBecomeActive | didResignActive |
|---|---|---|
| FilerSessionState | `window.makeFirstResponder(session.focusableView)` | (なし) |
| TerminalSessionState | `window.makeFirstResponder(session.focusableView)` | (なし) |
| WebSessionState | `window.makeFirstResponder(session.focusableView)` | (なし) |
| KitSessionState | `isFocused = true` (SwiftUI @FocusState) | (なし) |
| PreviewSessionState | `makeFirstResponder(session.focusableView)` (focusableView は子ビューが動的設定) | (なし) |

### 設計上の利点

1. **refocusActiveSession() の廃止**: ContentView は activeSessionID 変更時に
   `session.didBecomeActive()` を呼ぶだけ。何をするかは Session が決める
2. **拡張性**: 将来「アクティブ時にデータリロード」「非アクティブ時にポーリング停止」等のフックを
   各 SessionState に追加するだけで済む (集中管理の if/else 分岐が不要)
3. **責務の分離**: 「自分がアクティブになったら何をすべきか」を各 Session が自分で知っている。
   ContentView や SessionRegistry はライフサイクルイベントを発火する責務だけを持つ

### 呼び出しフロー

```
activePaneID or Pane.activeIndex が変わった
  │
  ├─ 前の activeSessionID を取得
  │    └─ 前の session.state.didResignActive(session:) を呼ぶ
  │
  └─ 新しい activeSessionID を計算
       └─ 新しい session.state.didBecomeActive(session:) を呼ぶ
            │
            ├─ Filer → makeFirstResponder(outlineView)
            ├─ Terminal → makeFirstResponder(terminalView)
            ├─ Kit → isFocused = true
            └─ Preview → makeFirstResponder(focusableView ?? focusCatcher)
```

### フォーカス管理の責務移譲

| Before | After |
|---|---|
| ContentView がフォーカスの種類を判断 | ContentView は `didBecomeActive` を呼ぶだけ |
| SessionRegistry.refocusActiveSession() が全 Session の分岐を持つ | 各 SessionState が自分でフォーカス処理 |
| focusableView(for:) で tool 種別で switch | Session.focusableView の有無を session 自身が判断 |

## 未決定事項

- FocusCatcherView を使う Session とそうでない Session の境界をどう表現するか
- Session.focusableView の変更を ContentView がどう検知するか (Observable にするか、明示的な refocus 呼び出しか)
- Session の生成/破棄と Tab の追加/クローズのトランザクション的な扱い
- Pane.id の永続化: 現在は `UUID()` で毎回新規生成。LayoutNodeSnapshot に paneID を追加する必要
- activeSessionID (computed) の変更検知方法: didSet は stored property にしか使えないので、
  activePaneID / activeIndex 変更時に手動で比較・通知するか、別のオブザーバ機構を導入するか
