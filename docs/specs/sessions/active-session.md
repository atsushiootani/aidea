# アクティブ Session の仕組み

Window 内で「現在どの Session にフォーカスしているか」を追跡・切替する仕組み。
Session 概念自体の位置づけは [ui-rules.md#概念モデル](./ui-rules.md#概念モデル) と [../glossary.md](../glossary.md) を参照。

---

## 基本ルール

- `SessionRegistry.activeSessionID` が Window 全体で **1 つの Active Session** を保持する
- Tab クリック、またはセッションビュー内のクリック (SwiftUI 領域のみ) で切替される
- `activeSessionID` の変更履歴は `activeHistory` に蓄積される (**最大 50 件**)

---

## クリックによる自動アクティブ化

すべての Session は、ビュー上をクリックしたときに **自動的にアクティブセッションになる**。
仕組みは `SessionRegistry.createSession` 内で全 Session に共通登録される NSEvent local monitor により実現され、**新しい Tool を追加する際に個別の実装は不要**。

### 仕組み

1. `createSession` 時に各 Session に対して `NSEvent.addLocalMonitorForEvents(.leftMouseDown)` を登録
2. クリック位置 (`hitTest`) が `session.focusableView` の子孫 (`isDescendant(of:)`) かチェック
3. マッチし、かつ現在の `activeSessionID` と異なれば `activateSession(session.id)` を呼ぶ
4. `activateSession` がペイン + タブを逆引きして `setActiveTab` → ライフサイクル (activate/deactivate) が発火

### 新しい Tool を追加するときの注意

- 共通モニタは `session.focusableView` に依存する。新しい Tool の子ビューが AppKit の NSView を持つ場合、**`session.focusableView` に必ずそのビューをセットする** (セットしないとクリック検知が効かない)
- 純 SwiftUI コンテンツの場合は `FocusCatcherView` を `.background()` に配置して `session.focusableView` に報告する

---

## Filer ダブルクリック時の挙動

Filer でファイルをダブルクリックすると Preview Session を新規作成するが、
**どのペインに作るか** を履歴から決定する:

1. `activeHistory` をさかのぼる
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
