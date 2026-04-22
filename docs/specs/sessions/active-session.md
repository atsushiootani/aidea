---
title: アクティブ Session の仕組み
description: SessionRegistry.activeSessionID の切替・履歴 (50 件)・Filer ダブルクリック挙動・Preview 開き規約 (openPreview / openPreviewAsSibling / openPreviewAtSlot)
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/decisions/0013-session-as-first-class-object.md
syncs_with:
  - docs/specs/sessions/focus-contract.md
  - docs/specs/aspects/persistence.md
impacts:
  - docs/specs/tools/filer.md
  - docs/specs/tools/preview.md
  - docs/specs/sessions/preview.md
  - docs/specs/window/active-session-switcher.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-22
---

# アクティブ Session の仕組み

Window 内で「現在どの Session にフォーカスしているか」を追跡・切替する仕組み。
Session 概念自体の位置づけは [ui-rules.md#概念モデル](./ui-rules.md#概念モデル) と [../glossary.md](../glossary.md) を参照。

---

## 基本ルール

- `SessionRegistry.activeSessionID` が Window 全体で **1 つの Active Session** を保持する
- Tab クリック、またはセッションビュー内のクリック (SwiftUI 領域のみ) で切替される
- `activeSessionID` の変更履歴は `activeSessionHistory` に蓄積される

## activeSessionHistory の更新ルール

- 末尾が最新、先頭が最古
- 同一 SessionID は **1 度しか含まれない** (新たに active になった時点で古い位置から削除して末尾に追加)
- **最大 50 件**。超えたら古い方から自動破棄
- **Tab クローズで該当 SessionID を履歴から除去** (`destroySession(_:)` 内で実施)
- **`workspace.json` (v5) に永続化される**。詳細は [persistence.md](../aspects/persistence.md#workspacejson-レイアウトsession-状態コンパニオンレコメンド統合) を参照

利用箇所:
- Filer ダブルクリック時の Preview 配置先決定 (後述)
- [Active Session Switcher](../window/active-session-switcher.md) (`Ctrl+Tab` で履歴を辿るウィンドウ) の表示元データ

---

## クリックによる自動アクティブ化

すべての AppKit 系 Session は、ビュー上をクリックしたときに **自動的にアクティブセッションになる**。
仕組みは `SessionRegistry.createSession` 内で AppKit 系 Session (`FocusBridgeOwner` 準拠の SessionState) に共通登録される NSEvent local monitor により実現され、**新しい Tool を追加する際に個別の実装は不要**。

### 仕組み

1. `createSession` 時に各 Session に対して `NSEvent.addLocalMonitorForEvents(.leftMouseDown)` を登録
2. クリック位置 (`hitTest`) が `state.focusBridge.trackedView` の子孫 (`isDescendant(of:)`) かチェック
3. マッチし、かつ現在の `activeSessionID` と異なれば `activateSession(session.id)` を呼ぶ
4. `activateSession` がペイン + タブを逆引きして `setActiveTab` → ライフサイクル (activate/deactivate) が発火

### 新しい Tool を追加するときの注意

- 共通モニタは `state.focusBridge.trackedView` に依存する。AppKit 系の SessionState を新規に追加する場合は、`FocusBridgeOwner` に準拠させ、NSViewRepresentable の `makeNSView` 内で `state.focusBridge.setView(_:)` を呼ぶこと (セットしないとクリック検知が効かない)
- 純 SwiftUI 系 SessionState (Kit 等) は本モニタの対象外。SwiftUI の gesture 機構 (`.onTapGesture` 等) でアクティブ化する経路を各 View が自前で用意する
- フォーカス契約 (C1 / C2 / C3) と `SessionFocusBridge` の責務は [focus-contract.md](./focus-contract.md) を参照

---

## Filer ダブルクリック時の挙動

Filer でファイルをダブルクリックすると Preview Session を新規作成するが、
**どのペインに作るか** を履歴から決定する:

1. `activeSessionHistory` をさかのぼる
2. 「**非 Filer ペインの最新 Session**」を探す
3. そのペインに新しい Preview Session タブを作成する

これにより、ユーザーが直前まで操作していたペインに自然に Preview が開く。

---

## Preview を開くときの呼び出し規約

ファイル/リソースを Preview Session として開くときは、必ず `SessionRegistry.openPreview(for:title:)` を使う。呼び出し側 (Filer / Kit / 他) は以下を守ること:

1. **呼び出し前に `registry.activeSessionID = <自分の SessionID>` を設定する**
   (openPreview はアクティブ Session のペインを「呼び出し元ペイン」として扱い、そのペインを避けて新しい Preview タブを配置するため)
2. **表示名がファイル名と異なる場合は `title` パラメータを渡す**
   (例: Kit の Skill は `title: "diagram.architecture"`、ファイル名 `SKILL.md` にしたくない場合)
3. 同じファイルの Preview が既に存在する場合は **新規作成せずそのタブをアクティブ化** する (openPreview が内部で dedupe する)
4. Preview タブが配置されるペインは以下のルールで決まる:
   - アクティブ履歴を新しい順にたどり、呼び出し元ペイン **以外** に属していた最新 Session のペインに配置
   - 該当がなければ呼び出し元ペイン以外の最初のペインにフォールバック

### Preview 内から Preview を開く場合 (sibling 配置)

Preview 内のリンククリックや翻訳ボタンから別のファイルを開く場合は `SessionRegistry.openPreviewAsSibling(for:title:)` を使う。`openPreview` とは配置ルールが異なる:

- **同じペインの呼び出し元タブの右隣**に新しい Preview タブを挿入する
- 同じ URL の Preview が既に存在する場合は dedupe (新規作成せずアクティブ化)
- 呼び出し元ペインが特定できない場合は `openPreview` にフォールバック

利用箇所:
- `MarkdownContainer` — Markdown 内のリンククリック / 翻訳版の表示
- `PreviewSessionView` — テキストファイルの翻訳版の表示

### TabSlot にドラッグ&ドロップで Preview を開く場合 (slot 指定配置)

Filer や外部アプリ (Finder 等) からファイルを TabSlot にドロップした場合は `SessionRegistry.openPreviewAtSlot(for:pane:index:title:)` を使う。`openPreview` / `openPreviewAsSibling` とは配置ルールが異なる:

- **ドロップされた TabSlot の `pane` + `index` 位置** に新しい Preview タブを挿入する
- 同じ URL の Preview が既に存在する場合は **dedupe** (新規作成せずアクティブ化。slot 位置への移動は行わない)
- 複数ファイル同時ドロップ時は `index`, `index+1`, `index+2`, ... と連続挿入
- ディレクトリは呼び出し元 (`TabSlotView`) が受け入れないため、この経路には来ない

利用箇所:
- `TabSlotView` — Filer / Finder からの fileURL ドロップ
