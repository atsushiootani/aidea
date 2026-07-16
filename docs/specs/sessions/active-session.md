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
last_updated: 2026-07-13
---

# アクティブ Session の仕組み

Window 内で「現在どの Session にフォーカスしているか」を追跡・切替する仕組み。
Session 概念自体の位置づけは [ui-rules.md#概念モデル](./ui-rules.md#概念モデル) と [../glossary.md](../glossary.md) を参照。

---

## 基本ルール

- [SessionRegistry](../glossary.md) の `activeSessionID` が Window 全体で **1 つの Active Session** を保持する
- Tab クリック、またはセッションビュー内のクリック (SwiftUI 領域のみ) で切替される
- `activeSessionID` の変更履歴は [`activeSessionHistory`](../glossary.md) に蓄積される

## activeSessionHistory の更新ルール

- 末尾が最新、先頭が最古
- 同一 SessionID は **1 度しか含まれない** (新たに active になった時点で古い位置から削除して末尾に追加)
- **最大 50 件**。超えたら古い方から自動破棄
- **Tab クローズで該当 SessionID を履歴から除去** (セッション破棄処理内で実施)
- **`workspace.json` (v5) に永続化される**。詳細は [persistence.md](../aspects/persistence.md#workspacejson-統合スナップショット) を参照

利用箇所:
- Filer ダブルクリック時の Preview 配置先決定 (後述)
- [Active Session Switcher](../window/active-session-switcher.md) (`Ctrl+Tab` で履歴を辿るウィンドウ) の表示元データ

---

## クリックによる自動アクティブ化

すべての AppKit 系 Session は、ビュー上をクリックしたときに **自動的にアクティブセッションになる**。
仕組みはセッション生成時に SessionRegistry が AppKit 系 Session (フォーカスブリッジを持つ Session 状態) へ共通登録するクリックモニタにより実現され、**新しい Tool を追加する際に個別の実装は不要**。

### 仕組み

1. セッション生成時に、各 Session に対してクリック (左マウスダウン) を監視するローカルモニタを登録する
2. クリック位置がフォーカスブリッジに登録された追跡対象 View の子孫かをチェックする
3. マッチし、かつ現在のアクティブ Session と異なればその Session をアクティブ化する
4. アクティブ化はペイン + タブを逆引きしてアクティブタブを切り替え、ライフサイクル (アクティブ化 / 非アクティブ化) が発火する
5. モニタの解除トークンは SessionRegistry が SessionID ごとに保持し、Tab クローズ (セッション破棄) で必ず解放する。
   解放しないとタブの開閉を繰り返すたびに無効なクロージャが溜まり続ける (issue #263)。詳細な仕組みとライフサイクル表は
   [conventions/implementations/focus.md#サブクラス不可能な-nsview-のクリック検知-クリックモニタ](../../conventions/implementations/focus.md#サブクラス不可能な-nsview-のクリック検知-クリックモニタ) を参照

### 新しい Tool を追加するときの注意

- 共通モニタはフォーカスブリッジに登録された追跡対象 View に依存する。AppKit 系の Session 状態を新規に追加する場合は、フォーカスブリッジを持たせ、View 生成時に追跡対象 View を登録すること (登録しないとクリック検知が効かない)。登録責任の詳細は [conventions/implementations/focus.md](../../conventions/implementations/focus.md) を参照
- 純 SwiftUI 系の Session 状態 (Kit 等) は本モニタの対象外。SwiftUI のタップ検知でアクティブ化する経路を各 View が自前で用意する
- フォーカス契約 (C1 / C2 / C3) は [focus-contract.md](./focus-contract.md)、その実装規約は [conventions/implementations/focus.md](../../conventions/implementations/focus.md) を参照

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

ファイル/リソースを Preview Session として開くときは、必ず SessionRegistry の **Preview 開き口 (通常配置)** を使う。呼び出し側 (Filer / Kit / 他) は以下を守ること:

1. **呼び出し前に自分の SessionID をアクティブ Session に設定する**
   (通常配置はアクティブ Session のペインを「呼び出し元ペイン」として扱い、そのペインを避けて新しい Preview タブを配置するため)
2. **表示名がファイル名と異なる場合は表示名を渡す**
   (例: Kit の Skill は表示名 `diagram.architecture`、ファイル名 `SKILL.md` にしたくない場合)
3. 同じファイルの Preview が既に存在する場合は **新規作成せずそのタブをアクティブ化** する (開き口が内部で dedupe する)
4. Preview タブが配置されるペインは以下のルールで決まる:
   - アクティブ履歴を新しい順にたどり、呼び出し元ペイン **以外** に属していた最新 Session のペインに配置
   - 該当がなければ呼び出し元ペイン以外の最初のペインにフォールバック

### Preview 内から Preview を開く場合 (sibling 配置)

Preview 内のリンククリックや翻訳ボタンから別のファイルを開く場合は **sibling 配置**の開き口を使う。通常配置とは配置ルールが異なる:

- **同じペインの呼び出し元タブの右隣**に新しい Preview タブを挿入する
- 同じ URL の Preview が既に存在する場合は dedupe (新規作成せずアクティブ化)
- 呼び出し元ペインが特定できない場合は通常配置にフォールバック

利用箇所:
- Markdown 表示コンテンツ — Markdown 内のリンククリック / 翻訳版の表示
- Preview のテキスト表示 — テキストファイルの翻訳版の表示
- ターミナル — ターミナル出力中のファイルパス クリック起動 (issue #71)。ターミナル作業中に他ペインへフォーカスを奪われない方が体感が自然なため通常配置ではなくこちらを使う
- GitDiff — Enter キーでフォーカスファイルを Preview に開く ([git-diff.md#プレビュージャンプ](./git-diff.md#プレビュージャンプ))。GitDiff 作業中に他ペインへフォーカスを奪われない方が体感が自然なため、ターミナルと同じポリシー

### TabSlot にドラッグ&ドロップで Preview を開く場合 (slot 指定配置)

Filer や外部アプリ (Finder 等) からファイルを [TabSlot](../glossary.md) にドロップした場合は **slot 指定配置**の開き口を使う。通常配置 / sibling 配置とは配置ルールが異なる:

- **ドロップされた TabSlot のペイン + 位置** に新しい Preview タブを挿入する
- 同じ URL の Preview が既に存在する場合は **dedupe** (新規作成せずアクティブ化。slot 位置への移動は行わない)
- 複数ファイル同時ドロップ時はドロップ位置から順に連続挿入する
- ディレクトリは呼び出し元の TabSlot が受け入れないため、この経路には来ない

利用箇所:
- TabSlot — Filer / Finder からの fileURL ドロップ
