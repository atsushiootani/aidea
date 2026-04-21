---
title: Session 内部状態: Preview
description: PreviewSessionState の状態 (url / title)・openPreview 呼び出し規約・workspace.json 永続化
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/sessions/active-session.md
  - docs/specs/sessions/focus-contract.md
syncs_with:
  - docs/specs/tools/preview.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-21
---

# Session 内部状態: Preview

`preview` Tool の Session は `PreviewSessionState` (`@Observable`) として状態を保持する。
ファイル/リソースを NSTextView / NSImage / WebView (drawio) で表示する。

Tool 仕様は [../tools/preview.md](../tools/preview.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `url` | `URL?` | プレビュー中のファイル URL | ✅ |
| `title` | `String?` | タブ表示名 (Kit からの `diagram.architecture` 等) | ✅ |
| `focusBridge` | `SessionFocusBridge` | AppKit 系コンテンツ (text / drawio / markdown edit) のフォーカス契約 (C1/C2/C3) 履行用ヘルパ。`FocusBridgeOwner` 経由。非永続 | — |
| `isActive` | `Bool` | 純 SwiftUI コンテンツ (markdown view / image) の `@FocusState` バインド用フラグ。非永続 | — |

Preview はコンテンツ種別で NSView 系 / 純 SwiftUI 系が切り替わるため、両方のフォーカス経路を併設する。
`didBecomeActive` で `focusBridge.activate()` と `isActive = true` の両方を発火し、実際に firstResponder を取るのは、その時点で有効な子ビュー側 (NSViewRepresentable が `setView` 済か、`.focused($isActive)` がバインドされているか) のどちらかになる。詳細は [focus-contract.md](./focus-contract.md) を参照。

## 開き方の規約

Preview は `SessionRegistry.openPreview(for:title:)` 経由で開く。
呼び出し側の義務 (activeSessionID の事前設定・title 指定・dedupe) は [active-session.md#preview-を開くときの呼び出し規約](./active-session.md#preview-を開くときの呼び出し規約) を参照。

## 永続化

`url` と `title` は `<projectRoot>/.aidea/workspace.json` に保存される。詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。
