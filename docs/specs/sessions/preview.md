---
title: Session 内部状態: Preview
description: Preview Tool の状態 (url / title)・openPreview 呼び出し規約・workspace.json 永続化・Scene とレコメンドプロンプト
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/sessions/active-session.md
  - docs/specs/sessions/focus-contract.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/preview.md
  - docs/specs/aspects/persistence.md
  - docs/specs/companions/recommend-mode.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# Session 内部状態: Preview

`preview` Tool の Session 状態を管理する。表示する URL とタイトルを保持する。
ファイル/リソースを NSTextView / NSImage / WebView (drawio) で表示する。

Tool 仕様は [../tools/preview.md](../tools/preview.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `url` | `URL?` | プレビュー中のファイル URL | ✅ |
| `title` | `String?` | タブ表示名 (Kit からの `diagram.architecture` 等) | ✅ |
| フォーカスブリッジ | — | AppKit 系コンテンツ (text / drawio / markdown edit) のフォーカス契約 (C1/C2/C3) 履行用ヘルパ。非永続 | — |
| `isActive` | `Bool` | 純 SwiftUI コンテンツ (markdown view / image) のフォーカスバインド用フラグ。非永続 | — |

Preview はコンテンツ種別で AppKit 系 / 純 SwiftUI 系が切り替わるため、両方のフォーカス経路を併設する。
アクティブ化時にフォーカスブリッジとアクティブフラグの両方を発火し、実際に firstResponder を取るのは、その時点で有効な子ビュー側のどちらかになる。詳細は [focus-contract.md](./focus-contract.md) を参照。

## 開き方の規約

Preview は `SessionRegistry.openPreview(for:title:)` 経由で開く。
呼び出し側の義務 (activeSessionID の事前設定・title 指定・dedupe) は [active-session.md#preview-を開くときの呼び出し規約](./active-session.md#preview-を開くときの呼び出し規約) を参照。

## 永続化

`url` と `title` は `<projectRoot>/.aidea/workspace.json` に保存される。詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `currentScene()` | 場面 |
|---|---|
| `"preview"` | Preview ツール全体 (現行は単一 Scene) |

- 将来的にコンテンツ種別 (markdown / image / drawio) や編集モードで分岐する余地あり (例: `"preview:markdown:view"` / `"preview:markdown:edit"`)。**現時点では単一 Scene `"preview"` で開始** し、必要性が出た段階で細分化する。
- 初期プロンプトは空配列 (`[]`)、`defaultCompanionIndex` は `0`。
