---
title: "0016: ターミナルの mouseMoved を NSEvent モニターで抑制する"
description: SwiftTerm の URL ホバー自動オープン誤発火を防ぐため NSEvent.addLocalMonitorForEvents で mouseMoved/Entered/Exited を握りつぶす判断
status: 採用
derived_from:
  - docs/decisions/0008-no-claude-autostart.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-16
---

# 0016: ターミナルの mouseMoved を NSEvent モニターで抑制する

**日付**: 2026-04-16

## 背景
SwiftTerm (`LocalProcessTerminalView`) は `NSTrackingArea(.activeAlways)` を登録し、
`mouseMoved` で URL をホバー検知してブラウザを自動で開く。
この挙動により以下の問題が発生していた：

1. **非アクティブタブでの誤発火**: ZStack + opacity 0 で隠しているタブの TerminalView にも
   `mouseMoved` が届き、裏のタブの URL が開かれる
2. **アクティブタブでもホバーで発火**: マウスを URL 上に置くだけで（クリックなしで）ブラウザが開く
3. **SwiftUI の `allowsHitTesting(false)` が無効**: NSView レベルの NSTrackingArea イベントには効かない

## 試したが不採用だったアプローチ

### 1. `mouseMoved` / `mouseUp` 等の override
SwiftTerm の `MacTerminalView` のメソッドは `public override` だが `open` ではないため、
モジュール外からの override が不可能。

```swift
// コンパイルエラー: overriding non-open instance method outside of its defining module
override func mouseMoved(with event: NSEvent) { ... }
override func mouseUp(with event: NSEvent) { ... }
override func updateTrackingAreas() { ... }
```

### 2. `layout()` 内での `removeTrackingArea`
`layout()` 後に SwiftTerm が登録したトラッキングエリアを除去する方式。
しかし、SwiftTerm は `updateTrackingAreas()` でも再登録するため、
`layout()` での除去だけでは不十分だった。

### 3. `isActiveTab` フラグによる条件分岐
`didBecomeActive` / `didResignActive` で `isActiveTab` を切り替え、
非アクティブ時だけトラッキングエリアを除去する方式。
`updateTrackingAreas()` の override 不可と同じ理由で不十分。

## 判断
**NSEvent ローカルモニターで mouseMoved / mouseEntered / mouseExited を握りつぶす。**

```swift
mouseMoveMonitor = NSEvent.addLocalMonitorForEvents(
    matching: [.mouseMoved, .mouseEntered, .mouseExited]
) { [weak self] event in
    guard let self else { return event }
    if let hitView = event.window?.contentView?.hitTest(event.locationInWindow),
       hitView === self || hitView.isDescendant(of: self) {
        return nil  // 握りつぶす
    }
    return event
}
```

加えて、`TerminalLinkGuard` (terminalDelegate プロキシ) で `requestOpenLink` を
Cmd+Click の場合のみに制限する二重防御を行う。

## 理由
1. SwiftTerm のメソッドが `open` でないため、override による対処が不可能
2. `updateTrackingAreas()` も non-open で、トラッキングエリアの除去は SwiftTerm の再登録と競合する
3. NSEvent ローカルモニターはイベントが NSView に届く前に介入でき、SwiftTerm 内部の実装に依存しない
4. URL オープンは Cmd+Click で代替でき、ホバーでの自動オープンは不要

## トレードオフ
- ターミナル上での **マウスカーソル形状の変更** (URL 上でのポインタカーソル) が無効になる
- SwiftTerm の **マウスモード報告** (vim 等のマウス位置トラッキング) に影響する可能性がある
  → 現時点では問題なし。将来必要になれば mouseMode の状態に応じてフィルタを緩和する

## 関連
- Issue #54
- [ADR 0008: ターミナルで claude を自動起動しない](./0008-no-claude-autostart.md) — 同じく SwiftTerm の制約による判断
