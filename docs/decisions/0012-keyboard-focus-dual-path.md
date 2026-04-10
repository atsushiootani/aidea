# 0012: キーボードフォーカスは AppKit と SwiftUI の 2 経路で管理する

**日付**: 2026-04-10
**状態**: 採用

## 背景
Aidea の Session は 2 種類の UI 基盤で実装されている:

| Session | UI 基盤 | NSView の有無 |
|---|---|---|
| Filer | AppKit (NSOutlineView) | あり |
| Terminal | AppKit (SwiftTerm) | あり |
| Web | AppKit (WKWebView) | あり |
| Kit | SwiftUI | なし (内部に自動生成) |
| Preview | SwiftUI | なし (内部に自動生成) |

「アクティブタブが切り替わったら、そのタブの First Responder が即座にキーボード入力を受け取る」
を実現するために、**2 つのフォーカス経路**が必要になった。

## 検討した代替案

### 案 A: AppKit `makeFirstResponder` で統一
- AppKit 系: `window.makeFirstResponder(nsView)` を直接呼ぶ
- SwiftUI 系: NSHostingView の子ビュー階層を再帰探索して最初のフォーカス可能ビューを見つけて `makeFirstResponder`
- **問題**: SwiftUI の内部構造に依存する。SwiftUI のアップデートで壊れる可能性がある

### 案 B: SwiftUI `@FocusState` で統一
- 全 Session を SwiftUI FocusState で管理する
- AppKit 系ビューは NSViewRepresentable 内で `@FocusState` と NSView の First Responder を連動
- **問題**: AppKit 系 Session (特に Terminal) は既に First Responder の仕組みで動いており、
  SwiftUI FocusState と二重管理になって複雑化する

### 案 C: 2 経路方式 (採用)
- **AppKit 系**: `SessionRegistry.focusableView(for:)` が対応する NSView を返す →
  `ContentView.updateFirstResponder()` が `window.makeFirstResponder(nsView)` を呼ぶ
- **SwiftUI 系**: `focusableView(for:)` は nil を返す (何もしない) →
  各 Session View が自分で `onChange(of: registry.activeSessionID)` を監視し、
  自身の `@FocusState isFocused = true` にセットする →
  SwiftUI が内部的に管理する NSView を First Responder にする

## 判断
**案 C (2 経路方式)** を採用。

## 理由
1. **各 Session が自身の基盤 (AppKit / SwiftUI) のネイティブなフォーカス機構をそのまま使える**。
   AppKit は `keyDown(with:)` + First Responder、SwiftUI は `.onKeyPress` + `@FocusState`
2. **トリガーは統一**: どちらの経路も `registry.activeSessionID` の変更が起点。
   セッション間の切替ロジックは 1 箇所 (activeSessionID の setter) に集約されている
3. **実装の独立性**: AppKit 系 Session は SwiftUI の `@FocusState` を知らなくてよい。
   SwiftUI 系 Session は `makeFirstResponder` を知らなくてよい。互いに干渉しない
4. **2 経路は干渉しない**: `focusableView` が nil のとき updateFirstResponder は何もしない。
   SwiftUI 側は nil なら自分で isFocused をセットする。排他的な分岐

## 実装

### AppKit 系: ContentView.updateFirstResponder
```
activeSessionID 変更
  → registry.focusableView(for:) → NSView? (filer/terminal/web のみ non-nil)
  → window.makeFirstResponder(nsView)
```

### SwiftUI 系: 各 Session View の onChange
```
activeSessionID 変更
  → KitSessionView / PreviewSessionView の onChange が発火
  → isFocused = true
  → SwiftUI 内部の NSView が First Responder になる
  → .onKeyPress ハンドラがキー入力を受け取る
```

### focusableView の返却値

| Session | focusableView の返却 | First Responder 設定者 |
|---|---|---|
| Filer | `FileTreeViewController.outlineView` | `ContentView.updateFirstResponder` |
| Terminal | `TerminalSessionState.terminalView` | 同上 |
| Web | `WebSessionState.webView` | 同上 |
| Kit | nil (何もしない) | `KitSessionView.onChange` → `isFocused = true` |
| Preview | nil (何もしない) | `PreviewSessionView.onChange` → `isFocused = true` |

## トレードオフ
- 2 つの異なるフォーカス管理方式を知っている必要がある (新しい Session を追加するとき)
- SwiftUI 系の `.onKeyPress` で具体的なキー操作を追加するのは各 View 個別の作業になる
  (Ctrl+P/N 等の共通ナビゲーションを SwiftUI 側で再実装する必要)
- 将来 Filer や Terminal を SwiftUI ベースに書き換える場合はフォーカス方式を入れ替える

## 新しい Session を追加するときのルール
- **AppKit ベース**: `SessionRegistry.focusableView(for:)` に case を追加して NSView を返す
- **SwiftUI ベース**: Session View に `@FocusState` + `.focusable()` + `.focused()` +
  `onChange(of: registry.activeSessionID)` を追加する

## 関連
- [0011](./0011-cmd-w-via-nsevent-monitor.md) — Cmd+W は NSEvent monitor で横取り (メニュー経路の問題)
- [boundaries.md](../specs/boundaries.md#タブ--ペイン--ツール操作-グローバルショートカット) — グローバルショートカット一覧
