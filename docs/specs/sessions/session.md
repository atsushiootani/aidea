---
title: Session と SessionState
description: Session (全 Tool 共通の薄い入れ物クラス) と SessionState (Tool 固有実装、AppKit 系は SessionFocusBridge を保持) の関係・役割分担・ライフサイクル呼び出しフロー
derived_from:
  - docs/decisions/0013-session-as-first-class-object.md
  - docs/decisions/0018-session-and-state-separation.md
  - docs/decisions/0020-session-focus-bridge.md
syncs_with:
  - docs/specs/glossary.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/sessions/focus-contract.md
impacts:
  - docs/specs/sessions/*
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-21
---

# Session と SessionState

Aidea の Session 実体は、**汎用クラス `Session`** と **Tool ごとに 1 つ存在するプロトコル準拠クラス `SessionState`** の 2 階層で構成される。本ファイルは両者の責任分担・関係・ライフサイクル呼び出しフローを集約する。

用語の定義は [glossary.md](../glossary.md)、5 概念モデル全体は [ui-rules.md](./ui-rules.md)、各 Tool ごとの SessionState の詳細は per-tool spec ([filer.md](./filer.md) / [kit.md](./kit.md) / [terminal.md](./terminal.md) / [claude.md](./claude.md) / [web.md](./web.md) / [preview.md](./preview.md) / [git.md](./git.md) / [git-diff.md](./git-diff.md)) を参照。

---

## 関係図

```
┌──────────────────────────────────────┐
│  Session (汎用クラス、全 Tool 共通)     │
│  ─────────────────────────────────   │
│  let id: SessionID                    │
│  let state: any SessionState  ──────────┐
│                                          │
│  func activate()    ── 委譲 ──→ state.didBecomeActive()
│  func deactivate()  ── 委譲 ──→ state.didResignActive()
│                                          │
│  ※ AppKit 知識を持たない (NSView/firstResponder を直接扱わない)
└──────────────────────────────────────┘  │
                                          ▼
              ┌──────────────────────────────────────────┐
              │  SessionState (protocol)                  │
              │  ─────────────────────────────────────   │
              │  func didBecomeActive(session:)           │
              │  func didResignActive(session:)           │
              └──────────────────────────────────────────┘
                              ▲
       ┌──────────┬───────────┼──────────┬──────────┬──────────┐
       │          │           │          │          │          │
       ▼          ▼           ▼          ▼          ▼          ▼
  Filer~State Terminal~ Claude~  Web~  Preview~  Git~  GitDiff~       Kit~
   ─── AppKit 系 (focusBridge を保持) ───────────────         純 SwiftUI 系
                                                              (isActive フラグのみ)

  AppKit 系 SessionState
  ┌──────────────────────────────────────┐
  │  Tool 固有データ (cached, treeNodes 等) │
  │  let focusBridge: SessionFocusBridge  │ ← フォーカス契約 C1/C2/C3 を担当
  └──────────────────────────────────────┘

  純 SwiftUI 系 SessionState
  ┌──────────────────────────────────────┐
  │  Tool 固有データ                       │
  │  var isActive: Bool                   │ ← SwiftUI .focused() バインド先
  └──────────────────────────────────────┘
```

---

## Session クラス

`Aidea/Tools/Session.swift` で定義される **汎用 `@Observable` クラス**。全 Tool で共通の 1 クラスで、Session 実体ごとにインスタンスが作られる。

- `id: SessionID` — Window 内で一意の識別子
- `state: any SessionState` — Tool 固有の状態への参照
- `activate()` / `deactivate()` — ライフサイクルイベントの **発火責任者**。中で `state.didBecomeActive` / `state.didResignActive` に委譲する
- **AppKit 知識を持たない**: NSView や `makeFirstResponder` といった AppKit API を直接扱わない (ADR 0020)

---

## SessionState プロトコル

`Aidea/Tools/Tool.swift` で定義される **プロトコル**。Tool ごとに 1 つの具体実装クラスが存在する。

- Tool 固有のデータと振る舞いを保持する場所
- `didBecomeActive(session:)` / `didResignActive(session:)` のフックメソッドを実装する (default 実装は no-op)
- 永続化対象 (workspace.json) のフィールドはここに置く

### AppKit 系 / 純 SwiftUI 系の区別

各 SessionState は **AppKit 系**または**純 SwiftUI 系**のいずれかとして実装される。区別は持つフィールドの種類で表現する。

| 種別 | 持つフィールド | フォーカス制御の手段 |
|---|---|---|
| **AppKit 系** | `let focusBridge: SessionFocusBridge` | `didBecomeActive` で `focusBridge.activate()`、`didResignActive` で `focusBridge.deactivate()` を呼ぶ |
| **純 SwiftUI 系** | `var isActive: Bool` | `didBecomeActive` で `isActive = true`、`didResignActive` で `isActive = false`。SwiftUI の `.focused($isActive)` が内部 NSView の firstResponder 出し入れを自動処理 |

`SessionFocusBridge` の責務とフォーカス契約 (C1 / C2 / C3) の詳細は [focus-contract.md](./focus-contract.md) を参照。

---

## 役割分担

| 観点 | Session (1 クラス) | SessionState (8 個の実装) |
|---|---|---|
| **数** | 全 Tool で 1 クラス共通 | Tool ごとに 1 クラス |
| **インスタンス** | 各 Session 実体ごとに 1 つ | Session 1 つに 1 つ紐付く |
| **Tool 固有データ** | 持たない | **持つ** (PTY cached / URL / treeNodes 等) |
| **`id`** | 持つ (`SessionID`) | 持たない |
| **AppKit 知識** | **持たない** | AppKit 系 state のみ持つ (`focusBridge` 経由で閉じ込め) |
| **アクティブ化のエントリポイント** | `activate()` を持つ (registry が呼ぶ) | `didBecomeActive(session:)` を実装 (Session が委譲) |
| **フォーカス契約 (C1/C2/C3)** | 関与しない | `focusBridge` (AppKit 系) または `isActive` (SwiftUI 系) で履行 |
| **永続化対象** | `id` のみ | Tool 固有の状態すべて (`focusBridge` / `isActive` は非永続) |
| **誰が生成するか** | `SessionRegistry.createSession()` | Session 生成時に同時に作る |

---

## Tool ごとの SessionState 実装

Tool ごとの実装の違いは **すべて SessionState 側**にある。各 SessionState の Tool 固有データと振る舞いの概観:

| SessionState | 種別 | Tool 固有のデータ | Tool 固有の振る舞い |
|---|---|---|---|
| **FilerSessionState** | AppKit 系 | `selectedFile`, `expandedURLs`, `excludeRules`, `controller (FileTreeViewController)` | ファイルツリー操作 |
| **TerminalSessionState** | AppKit 系 | `cached: PersistentTerminalView?`, `terminalView` lazy | PTY 起動 |
| **ClaudeSessionState** | AppKit 系 | `cached`, `companionPrompt`, `terminalView` lazy, `sendMessage` | claude CLI 自動起動 |
| **WebSessionState** | AppKit 系 | `url`, `cached: WKWebView?`, `urlObservation` | URL 永続化、ナビゲーション追従 |
| **PreviewSessionState** | AppKit 系 / 純 SwiftUI 系 (コンテンツ次第) | `url`, `title` | コンテンツ種別自動判定。NSView 系コンテンツ (text/drawio) では focusBridge を使い、純 SwiftUI コンテンツ (markdown/image) では isActive を使う |
| **GitSessionState** | AppKit 系 | `mode`, `treeNodes`, `selectedPath`, `fileStats`, `currentBranch` | git status 取得・パース |
| **GitDiffSessionState** | AppKit 系 | `mode`, `diffOutput`, `viewedFiles`, `focusedFile` | git diff 取得・パース |
| **KitSessionState** | 純 SwiftUI 系 | 4 つの Loader, `expandedSections`, `selection`, `isActive` | リソース読み込み |

各フィールドの詳細仕様 (ペイン移動での保持・永続化対象等) は per-tool spec ([filer.md](./filer.md) ほか) を SSoT とする。本表は概観のみ。

---

## ライフサイクル呼び出しフロー

```
ユーザーがタブをクリック (or Cmd+[ など)
    │
    ▼
SessionRegistry.setActiveTab(paneID:tabIndex:)
    │
    ├─ 旧 Session.deactivate()  ──→  state.didResignActive(session: self)
    │                                    ├─ AppKit 系: state.focusBridge.deactivate()
    │                                    │             (firstResponder を解放、契約 C2)
    │                                    └─ SwiftUI 系: state.isActive = false
    │                                                  (SwiftUI が .focused() 経由で自動解放)
    │
    └─ 新 Session.activate()    ──→  state.didBecomeActive(session: self)
                                         ├─ AppKit 系: state.focusBridge.activate()
                                         │             (NSView を firstResponder に、契約 C1)
                                         └─ SwiftUI 系: state.isActive = true
                                                       (SwiftUI が .focused() 経由で自動取得)
```

**Session が「ライフサイクルイベントの発火」を担当**し、**SessionState が「そのイベントで何をするか」を Tool ごとに実装**する分業構造。Session クラス自身はフォーカス制御に関与せず、AppKit 知識を持たない。

`activate()` / `deactivate()` を呼ぶのは `SessionRegistry.setActiveTab` の責務。直接 `state.didBecomeActive` を呼んではならない。アクティブ Session 切替の規約は [active-session.md](./active-session.md) を参照。

---

## 設計の経緯

| 段階 | 焦点の置き場所 | 経路分岐の判断 |
|---|---|---|
| ADR 0012 時代 | `SessionState.focusableView` (各 state が自前管理) | Tool 種別 (`switch tool`) |
| ADR 0013 時代 | `Session.focusableView` (Session に集約) | `focusableView` の有無 |
| **現行 (ADR 0020 採用)** | **`SessionState.focusBridge` (AppKit 系のみ) + `isActive` (SwiftUI 系)** | **SessionState の型 (focusBridge を持つか)** |

ADR 0020 で Session クラスから `focusableView` プロパティを撤去し、フォーカス契約を SessionState に委譲する形に進化させた。Session を first-class object とする ADR 0013 の核心判断は維持される。詳細は [ADR 0020](../../decisions/0020-session-focus-bridge.md) を参照。

---

## なぜ Session と SessionState を分けるか

`Session` は `id` と `state` への参照しか持たない薄い入れ物に見えるため、「`SessionState` に `id` を持たせて統合すれば `Session` クラスは不要では」という疑問が起きやすい。技術的には統合可能だが、protocol の stored property 制約・永続化境界・型消去の局所化・ライフサイクル責任の明確化という 4 つの理由で分離を維持している。

→ 詳細な判断と理由は [ADR 0018](../../decisions/0018-session-and-state-separation.md) を参照。

---

## 関連

- [glossary.md](../glossary.md) — Session / SessionState / SessionID / SessionRegistry の用語定義
- [ui-rules.md](./ui-rules.md) — 5 概念モデル (Window / Pane / Tab / Session / Tool)
- [active-session.md](./active-session.md) — アクティブ Session の切替規約
- [focus-contract.md](./focus-contract.md) — Session 間でフォーカスの一貫性を担保する契約 (C1/C2/C3) と SessionFocusBridge の仕様
- [ADR 0013](../../decisions/0013-session-as-first-class-object.md) — Session を first-class object にする設計判断
- [ADR 0018](../../decisions/0018-session-and-state-separation.md) — Session と SessionState を分離して保持する判断と 4 つの理由
- [ADR 0020](../../decisions/0020-session-focus-bridge.md) — フォーカス契約を SessionState + SessionFocusBridge に委譲する設計
