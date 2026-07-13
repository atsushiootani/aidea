---
title: Session 内部状態: Preview
description: PreviewSessionState の状態 (url / title)・openPreview 呼び出し規約・workspace.json 永続化・Scene とレコメンドプロンプト
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
last_updated: 2026-07-13
---

# Session 内部状態: Preview

`preview` Tool の Session が保持する状態。
ファイル/リソースをテキスト / 画像 / WebView (drawio) で表示する。

Tool 仕様は [../tools/preview.md](../tools/preview.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| 状態 | 用途 | ペイン移動で保持 |
|---|---|---|
| URL | プレビュー中のファイル URL | ✅ |
| タブ表示名 | タブに表示する名前 (Kit から開いた `diagram.architecture` 等)。未指定ならファイル名 | ✅ |
| フォーカスブリッジ | AppKit 系コンテンツ (text / drawio / markdown 編集) のフォーカス契約 (C1/C2/C3) 履行用ヘルパ。非永続 | — |
| アクティブフラグ | 純 SwiftUI コンテンツ (markdown 表示 / 画像) のフォーカスバインド用フラグ。非永続 | — |

Preview はコンテンツ種別で AppKit 系 / 純 SwiftUI 系が切り替わるため、両方のフォーカス経路を併設する。
アクティブ化時にはフォーカスブリッジのアクティブ化とアクティブフラグの設定を**両方**発火し、実際にキー入力の受け手になるのは、その時点で有効な子ビュー側 (AppKit 系の View が登録済みか、SwiftUI のフォーカスバインドが有効か) のどちらかになる。詳細は [conventions/implementations/focus.md](../../conventions/implementations/focus.md) を参照。

## 開き方の規約

Preview は [SessionRegistry](../glossary.md) の Preview 開き口 (通常配置) 経由で開く。
呼び出し側の義務 (アクティブ Session の事前設定・表示名指定・dedupe) は [active-session.md#preview-を開くときの呼び出し規約](./active-session.md#preview-を開くときの呼び出し規約) を参照。

## 永続化

URL とタブ表示名は `<projectRoot>/.aidea/workspace.json` に保存される。詳細は [../aspects/persistence.md](../aspects/persistence.md) を参照。

## Scene とレコメンドプロンプト

セッション共通の仕組み ([../frontchannels/scene.md](../frontchannels/scene.md)) で、Cmd+Enter のレコメンド送信に対応する。

| Scene 識別子 | 場面 |
|---|---|
| `"preview"` | Preview ツール全体 (現行は単一 Scene) |

- 将来的にコンテンツ種別 (markdown / image / drawio) や編集モードで分岐する余地あり (例: `"preview:markdown:view"` / `"preview:markdown:edit"`)。**現時点では単一 Scene `"preview"` で開始** し、必要性が出た段階で細分化する。
- 初期プロンプトは空、既定の Companion は index 0。
