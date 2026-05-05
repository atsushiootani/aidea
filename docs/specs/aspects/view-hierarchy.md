---
title: View 階層 (UI コンポーネント親子関係)
description: 実装上の SwiftUI / AppKit View の親子関係を AA で図示したリファレンス。「このボタンは XxxView の中の YyyView に置く」のような配置指示の参照元
derived_from:
  - docs/specs/architecture.md
  - docs/specs/sessions/ui-rules.md
syncs_with:
  - docs/specs/architecture.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/companions/companion.md
  - docs/specs/companions/recommend-mode.md
  - docs/specs/companions/speech-history.md
  - docs/specs/widgets/*
  - docs/specs/window/active-session-switcher.md
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/aspects/README.md
last_updated: 2026-05-05
---

# View 階層 (UI コンポーネント親子関係)

実装上の SwiftUI / AppKit View の親子関係を俯瞰するためのリファレンス。
「このボタンは `AppHeaderView` の中の `CompanionView` の隣に置きたい」のような
**位置指定をする際の参照元**として使う。

抽象的な 5 概念モデル (Window/Pane/Tab/Session/Tool) は
[../sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) を参照。
コードレイヤーの依存方向は [../architecture.md](../architecture.md) を参照。

---

## メインウィンドウ全体

`AideaApp` (`App/AideaApp.swift`) が `WindowGroup` でメインウィンドウを生成し、
ルートに `ContentView` を配置する。`projectRoot` が未設定なら `emptyState`
プレースホルダのみを表示し、設定済みなら以下の階層になる。

メインウィンドウの全体像は **ツリービュー** (親子の入れ子で表記)
と **トップダウンビュー** (画面に四角形を並べた俯瞰図) の 2 つの図で示す。
用途で使い分けてね:

- **ツリービュー** — 「どの View がどの View の中に置かれているか」を正確に追いたいとき
- **トップダウンビュー** — 「画面のどの位置に何があるか」を直感的に掴みたいとき

### ツリービュー

```
NSWindow (メインウィンドウ)
└─ ContentView                                    [Views/Layout/ContentView.swift]
   └─ VStack(spacing: 0)
      ├─ AppHeaderView                            [Views/Layout/AppHeaderView.swift]
      │  └─ HStack(spacing: 8)
      │     ├─ CompanionView                      [Views/Companion/CompanionView.swift]
      │     │  └─ VStack
      │     │     ├─ HStack (9 個のアイコン横並び)
      │     │     │  └─ ForEach companions
      │     │     │     └─ VStack (companionIcon)
      │     │     │        ├─ Button (60x60 アイコン画像 + stateOverlay)
      │     │     │        └─ Text (Companion 名)
      │     │     └─ RecommendBubbleView          [Views/Companion/RecommendBubbleView.swift]
      │     │        (recommend.isActive 時のみ。選択 Companion 直下に offset 表示)
      │     ├─ speechToggleButton (読み上げ ON/OFF)
      │     ├─ Spacer
      │     └─ WidgetView                         [Widgets/WidgetView.swift]
      │        └─ HStack (ヘッダ常駐 widget を右端に並べる)
      │           └─ TimerView                    [Widgets/Pomodoro/TimerView.swift]
      │              (フェーズアイコン + 残り時間 + Start/Pause + Reset + 進捗ゲージを常時表示)
      ├─ Divider
      └─ SplitLayoutView                          [Views/Layout/SplitLayoutView.swift]
         (NSViewControllerRepresentable — 以下は AppKit 側)
         └─ LayoutContainerViewController        [Views/Layout/LayoutContainerViewController.swift]
            └─ NSSplitViewController             ※LayoutNode の split 毎に再帰
               └─ NSHostingController(PaneView)  ※LayoutNode の leaf 毎
                  └─ (PaneView の階層へ続く)
```

#### Sheet / Popover (ContentView 階層に追加で乗るもの)

| トリガ | View | 親 |
|---|---|---|
| Companion 名タップ | `CompanionEditView` (`Views/Companion/CompanionEditView.swift`) | `CompanionView` の `.sheet` |
| CompanionEditView「speech 履歴を見る」ボタン | `SpeechHistoryView` (`Views/Companion/SpeechHistoryView.swift`) | `CompanionEditView` の `.sheet` |
| ScenePromptsEditorView の Companion アイコン | Popover (Companion ピッカー) | `ScenePromptsEditorView` (Session 下部) |

### トップダウンビュー

実際の画面に各 View がどう配置されるかを、座標的なボックスで表現したもの。
親子関係の正確さよりも「画面のどこに何があるか」を素早く掴むことを目的としている。

#### 単一 Pane (デフォルトレイアウト)

```
┌─ NSWindow / ContentView ───────────────────────────────────────────────┐
│ ┌─ AppHeaderView ────────────────────────────────────────────────────┐ │
│ │ ┌─ CompanionView ────────────────────────────┐  ┌──────┐           │ │
│ │ │ [1] [2] [3] [4] [5] [6] [7] [8] [9]        │  │  🔊  │  Spacer   │ │
│ │ └────────────────────────────────────────────┘  └──────┘           │ │
│ └────────────────────────────────────────────────────────────────────┘ │
│ ── Divider ─────────────────────────────────────────────────────────── │
│ ┌─ SplitLayoutView ──────────────────────────────────────────────────┐ │
│ │ ┌─ PaneView ─────────────────────────────────────────────────────┐ │ │
│ │ │ ┌─ tabBar (ScrollView) ──────────────┐         ┌─ split btns ┐ │ │ │
│ │ │ │ [Tab1] [Tab2] [Tab3] … [+]          │         │  [⇋]  [⇕]   │ │ │ │
│ │ │ └────────────────────────────────────┘         └─────────────┘ │ │ │
│ │ │ ── Divider ──────────────────────────────────────────────────── │ │ │
│ │ │ ┌─ sessionStack (ZStack — 全 Tab を常時保持) ─────────────────┐ │ │ │
│ │ │ │                                                             │ │ │ │
│ │ │ │                                                             │ │ │ │
│ │ │ │           <Tool>SessionView (アクティブな Tab の本体)        │ │ │ │
│ │ │ │           Filer / Kit / Terminal / Claude /                 │ │ │ │
│ │ │ │           Web / Preview / Git / GitDiff                     │ │ │ │
│ │ │ │                                                             │ │ │ │
│ │ │ │                                                             │ │ │ │
│ │ │ ├─────────────────────────────────────────────────────────────┤ │ │ │
│ │ │ │ ScenePromptsEditorView                                      │ │ │ │
│ │ │ │  [👧]  [prompt 1]  [prompt 2]  [+]                          │ │ │ │
│ │ │ └─────────────────────────────────────────────────────────────┘ │ │ │
│ │ └────────────────────────────────────────────────────────────────┘ │ │
│ └────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

#### 水平分割 (Cmd+Option+→ で生成)

`SplitLayoutView` 配下の `NSSplitView` が `isVertical = true` になり、垂直ディバイダで横並びの 2 ペインになる。
各ペインは独立した `PaneView` で、それぞれが自前の TabBar と SessionStack を持つ。

```
┌─ NSWindow / ContentView ───────────────────────────────────────────────┐
│ ┌─ AppHeaderView ────────────────────────────────────────────────────┐ │
│ │ [Companion×9]   [🔊]                                               │ │
│ └────────────────────────────────────────────────────────────────────┘ │
│ ┌─ SplitLayoutView (HSplit) ────────────┬───────────────────────────┐ │
│ │ ┌─ PaneView A ──────────────────────┐ │ ┌─ PaneView B ───────────┐ │ │
│ │ │ [Tabs]                  [⇋][⇕]    │ │ │ [Tabs]         [⇋][⇕]  │ │ │
│ │ │ ──────────────────────────────────│ │ │ ───────────────────────│ │ │
│ │ │                                   │ │ │                        │ │ │
│ │ │                                   │ │ │                        │ │ │
│ │ │   SessionView (例: Filer)          │ │ │  SessionView (例: Claude) │ │
│ │ │                                   │ │ │                        │ │ │
│ │ │                                   │ │ │                        │ │ │
│ │ │ ──────────────────────────────────│ │ │ ───────────────────────│ │ │
│ │ │ [ScenePromptsEditorView]          │ │ │ [ScenePromptsEditorView]│ │ │
│ │ └───────────────────────────────────┘ │ └────────────────────────┘ │ │
│ │                                       ↑                            │ │
│ │                          垂直 divider (NSSplitView)                 │ │
│ └───────────────────────────────────────┴───────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

#### 垂直分割 (Cmd+Option+↓ で生成)

`NSSplitView` が `isVertical = false` で、水平ディバイダで上下ペインになる。

```
┌─ SplitLayoutView (VSplit) ────────────────────────────────────────────┐
│ ┌─ PaneView A ──────────────────────────────────────────────────────┐ │
│ │ [Tabs]                                                  [⇋][⇕]    │ │
│ │ ───────────────────────────────────────────────────────────────── │ │
│ │   SessionView                                                     │ │
│ │ ───────────────────────────────────────────────────────────────── │ │
│ │ [ScenePromptsEditorView]                                          │ │
│ └───────────────────────────────────────────────────────────────────┘ │
│ ─────────────────── 水平 divider (NSSplitView) ───────────────────── │
│ ┌─ PaneView B ──────────────────────────────────────────────────────┐ │
│ │ [Tabs]                                                  [⇋][⇕]    │ │
│ │ ───────────────────────────────────────────────────────────────── │ │
│ │   SessionView                                                     │ │
│ │ ───────────────────────────────────────────────────────────────── │ │
│ │ [ScenePromptsEditorView]                                          │ │
│ └───────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────┘
```

`SplitLayoutView` は `LayoutNode` のツリーを再帰的に展開するため、HSplit と VSplit を
ネストすれば任意の格子状レイアウトが作れる (例: 左に 1 ペイン、右を上下分割で 2 ペイン)。

#### 一時的にメインレイアウトに重なるオーバーレイ

以下の View は条件付きでメインレイアウトに重なって描画される (常時表示ではない)。

| View | 重なる位置 | 発生条件 |
|---|---|---|
| `RecommendBubbleView` | `CompanionView` の選択中アイコン直下 (吹き出し) | `RecommendState.isActive` (Cmd+Enter で起動) |
| `CompanionEditView` | ウィンドウ全体の sheet | Companion 名ラベルをタップ |
| Tool 選択 NSMenu | `+` ボタン直下 / 任意位置 | `+` ボタン押下 / Cmd+T |
| `ActiveSessionSwitcherView` | 別 NSWindow (`level = .floating`、メインウィンドウ中央) | Ctrl+Tab |

---

## PaneView (1 つの物理ペイン)

`SplitLayoutView` が `LayoutNode` の leaf 毎に生成する。タブバーと
全 Session View を ZStack で常時レンダリングする ([ADR 0019](../../decisions/0019-all-tabs-zstack-rendering.md))。

```
PaneView                                          [Views/Layout/PaneView.swift]
└─ VStack(spacing: 0)
   ├─ tabBar : HStack
   │  ├─ ScrollView (.horizontal)
   │  │  └─ HStack
   │  │     ├─ TabSlotView (index: 0)             [Views/Layout/TabSlotView.swift]
   │  │     ├─ ForEach tabs
   │  │     │  ├─ tabItem (HStack: tabIcon + Text + xButton)
   │  │     │  └─ TabSlotView (index: i+1)
   │  │     └─ addButton (+ ボタン → Tool 選択 NSMenu)
   │  └─ splitButtons (左右分割 / 上下分割ボタン)
   ├─ Divider
   └─ sessionStack : ZStack (全 Tab 常時レンダリング)
      ├─ emptyTab                                 ※pane.tabs が空のとき
      └─ ForEach pane.tabs
         └─ SessionRegistry.view(for: id)         [Sessions/SessionRegistry.swift#view(for:)]
            (アクティブ以外は opacity(0) + allowsHitTesting(false))
            └─ (Session View の階層へ続く)
```

タブバー右上に出る `+` メニューの位置参照には `AddButtonAnchorView` (不可視
NSView の representable) を背景に敷く。Cmd+T も同じ NSMenu を共用する。

---

## Session View (`SessionRegistry.view(for:)` が返す内容)

`PaneView` の `sessionStack` 配下では `SessionRegistry.view(for:)` が
**Tool 種別ごとに `VStack(本体 + ScenePromptsEditorView)` を返す**統一パターン
で構築する。`ScenePromptsEditorView` は Cmd+Enter のレコメンド対象 Scene を
編集するエディタ ([recommend-mode.md](../companions/recommend-mode.md))。

```
SessionRegistry.view(for: id)                     [Sessions/SessionRegistry.swift]
└─ VStack(spacing: 0)
   ├─ <Tool>SessionView                            ※Tool 毎に下表
   └─ ScenePromptsEditorView                       [Views/Common/ScenePromptsEditorView.swift]
      └─ HStack
         ├─ companionMenu (デフォルト Companion アイコン Button → Popover)
         ├─ ForEach prompts (promptTag)
         ├─ addPrompt Button (+)
         └─ Spacer
```

例外: `gitDiff` のみ `GitDiffSessionContainer` で同等の `VStack` を自前で構成する。

### Tool 別の本体 View

| Tool | 本体 View (ファイル) | 内側の構造 |
|---|---|---|
| `filer` | `FilerSessionView` (`Sessions/Filer/FilerSessionView.swift`) | `NSViewControllerRepresentable` → `FileTreeViewController` の `NSStackView { searchField, NSScrollView { NSOutlineView } }` |
| `kit` | `KitSessionView` (`Sessions/Kit/KitSessionView.swift`) | `ScrollView` → `LazyVStack(pinnedViews: [.sectionHeaders])` の 4 セクション (Agents / Skills / Commands / MCP Servers) |
| `terminal` | `TerminalSessionView` (`Sessions/Terminal/TerminalSessionView.swift`) | `NSViewRepresentable` → `PersistentTerminalView` (SwiftTerm `LocalProcessTerminalView`) |
| `claude` | `ClaudeSessionView` (`Sessions/Claude/ClaudeSessionView.swift`) | `NSViewRepresentable` → `PersistentTerminalView` (Terminal と共用) |
| `web` | `WebSessionView` (`Sessions/Web/WebSessionView.swift`) | `NSViewRepresentable` → `WKWebView` |
| `preview` | `PreviewSessionView` (`Sessions/Preview/PreviewSessionView.swift`) | 拡張子で分岐: `DrawioPreview` / `MarkdownContainer` / `NSTextPreview` (`NSTextView`) / `Image` (NSImage) / placeholder |
| `git` | `GitSessionView` (`Sessions/Git/GitSessionView.swift`) | `NSViewControllerRepresentable` → `GitFileListViewController` (`branchBadge` + `picker(NSSegmentedControl)` + `NSScrollView { GitOutlineView }`) |
| `gitDiff` | `GitDiffSessionContainer` (`Sessions/Git/GitDiffSessionView.swift`) | `VStack { GitDiffSessionView, ScenePromptsEditorView }`。`GitDiffSessionView` は `NSViewRepresentable` → `GitDiffWebView` (`WKWebView` + diff2html) |

PreviewSessionView の Markdown は `MarkdownContainer` がさらに `MarkdownPreview`
(WKWebView ベース) と編集モード時の `EditableTextView` (NSTextView) を切り替える。
drawio は `DrawioPreview` が `DrawioStaticView` (画像表示) と `DrawioEditor`
(WKWebView) を切り替える。

---

## メインウィンドウ階層に乗らない補助 View

別 `NSWindow` / `NSPanel` で表示される View は ContentView 配下のツリーには
登場しない。

| View | ファイル | 表示形態 | 仕様 |
|---|---|---|---|
| `ActiveSessionSwitcherView` | `Views/Common/ActiveSessionSwitcherView.swift` | `borderless` NSWindow + `NSHostingView` ([ActiveSessionSwitcher.swift](../../../Aidea/Aidea/Sessions/ActiveSessionSwitcher.swift) が `level = .floating`) | [../window/active-session-switcher.md](../window/active-session-switcher.md) |
| Tool 選択 NSMenu (Cmd+T / `+`) | `PaneView.showToolPickerMenu` | `NSMenu.popUp()` | — |
| 「指定のアプリで開く」NSMenu | `FileTreeViewController.buildOpenWithMenu` | `NSMenu.popUp()` | [../tools/filer.md](../tools/filer.md) |
| ファイル名入力ダイアログ | `Sessions/Filer/FileNameInputDialog.swift` | `NSAlert` + accessoryView | [../tools/filer.md](../tools/filer.md) |
| 除外ルール / デコレーションルール ダイアログ | `Sessions/Filer/ExcludeRulesDialog.swift` / `DecorationRulesDialog.swift` | `NSAlert` accessoryView | [../tools/filer.md](../tools/filer.md) |

---

## 配置指示の例

このドキュメントを参照すれば以下のような指示が機械的に書ける。

- 「読み上げトグルの右隣にバッジを足したい」
  → `AppHeaderView.body` の `HStack` 内、`speechToggleButton` の後ろに挿入
- 「Companion アイコンの下にステータステキストを表示したい」
  → `CompanionView.companionIcon` の `VStack` (Button + Text 構造) に Text を追加
- 「Tab バー右端の分割ボタンの隣にメニューボタンを増やしたい」
  → `PaneView.splitButtons` の `HStack` に Button を追加
- 「Filer の各セッション View の下に footer を出したい」
  → `SessionRegistry.view(for: .filer)` の `VStack` に追加 (現状は本体 + `ScenePromptsEditorView`)

---

## 更新ルール

- View ファイルの追加 / 削除 / 親子関係の変更があったらこのドキュメントを更新する
- AA 図と本文は実装と 1:1 対応させる (stale を残さない)
- `/aidea.docs-healthcheck` で View 階層と実装の不整合がフラグされる
