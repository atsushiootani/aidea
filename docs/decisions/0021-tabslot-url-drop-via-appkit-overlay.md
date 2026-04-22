---
title: "0021: TabSlot のファイル URL ドロップは AppKit overlay で受ける"
description: Filer (NSOutlineView) から TabSlot へのファイルドロップを SwiftUI の dropDestination/onDrop ではなく NSViewRepresentable + registerForDraggedTypes で受ける設計
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-22
---

# 0021: TabSlot のファイル URL ドロップは AppKit overlay で受ける

**日付**: 2026-04-22

## 背景

Filer から TabSlot にファイルをドラッグ&ドロップして新規 Preview を開く機能 (issue #10) を実装するにあたり、`TabSlotView` がファイル URL の drop を受け付ける必要がある。

`TabSlotView` は元々 `dropDestination(for: SessionID.self)` を持ち、Window 内の SwiftUI ドラッグでタブを並び替える drop target として動いていた。ここに「Filer のファイルをドロップしたら Preview を開く」を追加する場合、最初の素直な実装は次の SwiftUI API のいずれかになる。

- `.dropDestination(for: URL.self)` (Transferable 系)
- `.onDrop(of: [UTType.fileURL], isTargeted:perform:)` (NSItemProvider 系)

## 問題

実装して試したところ、両 API とも **Filer の `NSOutlineView.outlineView(_:pasteboardWriterForItem:)` 経由で発生した drag を取りこぼす**ことが確認できた。同じプロセス内 (`forLocal: true`) で発火させたローカルドラッグであり、`registerForDraggedTypes([.fileURL])` / `setDraggingSourceOperationMask([.move, .copy], …)` も適切に設定済み、ペーストボードに `node.url as NSURL` が `.fileURL` タイプで載っていることも確認した。にもかかわらず SwiftUI 側の `isTargeted` クロージャすら呼ばれない。

これは SwiftUI の Transferable / NSItemProvider 経路が、AppKit の NSPasteboard ローカルドラッグからの URL 提供を確実には橋渡ししない既知の挙動 (= Apple のドキュメント化されていない実装ギャップ) によるもので、回避策がない。

## 決定

`TabSlotURLDropTarget: NSViewRepresentable` を新設し、`TabSlotView` に `.overlay` として被せて AppKit のドラッグディスパッチから直接ファイル URL を受ける。

```
TabSlotView
├─ Color.clear (12×22 hit area)
├─ overlay: 縦線 (4×22, ホバー時アクセントカラー)
├─ overlay: TabSlotURLDropTarget         ← AppKit drag (URL) を受ける
└─ dropDestination(for: SessionID.self)  ← SwiftUI drag (タブ移動) を受ける
```

`TabSlotURLDropTarget` の中身は `NSView` サブクラスで、`registerForDraggedTypes([.fileURL])` し、`draggingEntered` / `performDragOperation` で `isTargeted` フラグの更新と `SessionRegistry.openPreviewAtSlot(for:pane:index:)` の呼び出しを行う。マウスクリック等の通常イベントは `hitTest(_:)` で `nil` を返して下層 SwiftUI に通すため、SwiftUI 側の hover / SessionID drop と共存する。

## 結果

- **タブ移動 (SessionID drop)**: SwiftUI 内ドラッグなので `dropDestination(for: SessionID.self)` がそのまま機能する
- **ファイル投入 (URL drop)**: AppKit 経路で確実に届く
- **視覚フィードバック**: `isTargetedSession` (SwiftUI) と `isTargetedURL` (AppKit overlay の callback) を `||` で OR したものを縦線のハイライトに使う
- **コスト**: NSViewRepresentable 1 ファイル (`TabSlotURLDropTarget.swift`) と overlay 1 行の追加のみ

## 不採用案

| 案 | 理由 |
|---|---|
| `.dropDestination(for: URL.self)` のまま | NSOutlineView 由来 drag が届かない (本 ADR の動機) |
| `.onDrop(of: [UTType.fileURL])` (旧 API) | 同上。NSItemProvider 系も AppKit ローカル drag を取りこぼす |
| Filer 側を SwiftUI Draggable に書き換える | NSOutlineView ベースのファイラを丸ごと SwiftUI 化することになり、影響範囲が過大 |
| `NSPasteboardItem` に独自 type を追加 | NSPasteboard の content は Filer 内 D&D とも共有するため、独自 type を増やすとファイラ移動側の `validateDrop`/`acceptDrop` にも変更が波及する |

## 関連

- [docs/specs/tools/filer.md](../specs/tools/filer.md) — Filer の D&D 仕様
- [docs/specs/sessions/active-session.md](../specs/sessions/active-session.md) — TabSlot の役割
- ADR [0019: 全タブを ZStack で常時レンダリング](./0019-all-tabs-zstack-rendering.md) — 同様に SwiftUI と AppKit の境界で工夫する例
