---
title: レコメンドモード
description: Cmd+Enter で起動するコンパニオンプロンプト選択 UI・RecommendState/RecommendStore・Scene 解決とキー操作
derived_from:
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/companions/companion.md
  - docs/specs/aspects/keybindings.md
  - docs/specs/aspects/persistence.md
  - docs/specs/sessions/claude.md
  - docs/specs/sessions/filer.md
  - docs/specs/sessions/git.md
  - docs/specs/sessions/git-diff.md
  - docs/specs/sessions/kit.md
  - docs/specs/sessions/preview.md
  - docs/specs/sessions/terminal.md
  - docs/specs/sessions/web.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# レコメンドモード

> Cmd+Enter でコンパニオンにレコメンドプロンプトを提示し、選択・送信する UI

コンパニオンに [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) 経由でプロンプトを送る上位 UI。
コンパニオン本体は [companion.md](./companion.md) を参照。

---

## 概要

**レコメンドモード (Recommend Mode)** は、どのビューからでも Cmd+Enter で起動できる
コンパニオンへのプロンプト選択 UI。現在のビューに応じたレコメンドプロンプトを
コンパニオンアイコンの吹き出しに最大 3 つ表示し、選択して送信する。

---

## フロー

```
1. ユーザーがどのビューでも Cmd+Enter を押下
2. ヘッダのコンパニオンビューにフォーカスが移る
3. コンパニオン 0 号に吹き出しが表示される
4. 吹き出しに現在のビューに応じたレコメンドプロンプトが最大 3 つ縦に並ぶ
5. 上下キーでプロンプトを選択
6. 左右キーでコンパニオンを切替（吹き出しも一緒に移動、プロンプトは同じ）
7. 決定キー（Enter）で送信
   - 選択したコンパニオンの Claude セッションをアクティブにする
   - プロンプトを PTY に send() する
8. Esc でレコメンドモードを終了
```

---

## UI

```
┌─────────────────────────────────────────────────┐
│  [😺] [🦁] [🐦] [🐱] [🦊] [🐦] [🦋] [🦋]  + │  ← ヘッダ
│         ↑                                        │
│    ┌─────────────────┐                           │
│    │ コミットして      │                           │
│    │ プッシュして      │  ← 吹き出し（レコメンド）  │
│    │ PRを作って        │                           │
│    └─────────────────┘                           │
├─────────────────────────────────────────────────┤
│                   メインコンテンツ                  │
└─────────────────────────────────────────────────┘
```

- 吹き出しは選択中のコンパニオンアイコンの下に表示
- 選択中のプロンプトはハイライト表示
- 左右キーでコンパニオンを変えると、吹き出しが移動する
- プロンプトの内容は変わらない（コンパニオン共通）

---

## レコメンドプロンプトの提供

各ビュー（Tool の SessionState）が「**現在の Scene 識別子**」を提供する。Scene に紐付くプロンプト一覧自体は `RecommendStore` (起動時に `default-workspace.json` から流入する) が SSoT。

### プロトコル

```swift
protocol SessionState {
    /// 現在の Scene 識別子を返す
    func currentScene() -> String?
}
```

### 初期定義 (Bundle 同梱の `default-workspace.json` の `recommends` に格納)

| Scene | レコメンドプロンプト (初期値) | `defaultCompanionIndex` |
|--------|---------------------|---|
| `git:workingChanges` | `"コミットして"` `"プッシュして"` `"PRを作って"` | `0` |
| `git:prPreview` | `"PRをマージして"` `"レビューして"` | `0` |
| `gitDiff:workingChanges` | `"コミットして"` `"プッシュして"` `"PRを作って"` | `0` |
| `gitDiff:prPreview` | `"PRをマージして"` `"レビューして"` | `0` |
| `claude:0` … `claude:8` | `[]` (空。ユーザが各 Companion の役割に応じて追加) | Scene 識別子末尾の index と同値 (自 Companion) |
| `filer` | `[]` | `0` |
| `terminal` | `[]` | `0` |
| `preview` | `[]` | `0` |
| `kit` | `[]` | `0` |
| `web` | `[]` | `0` |
| 上記以外 | エントリ無し → Cmd+Enter は何もしない | — |

- **Claude Scene のみ `defaultCompanionIndex` が自 Companion に一致する** (`claude:5` なら `5`)。これにより Claude セッションで Cmd+Enter した際に、最初に選択されるのが「そのセッション自身が紐付く Companion」になる。
- 他セッションの初期 `defaultCompanionIndex` は `0` (= Companion 1)。ユーザが ScenePromptsEditorView から変更できる。
- `prompts` が空の Scene では Cmd+Enter しても吹き出しが出ない (レコメンドなし)。ユーザが ScenePromptsEditorView で追加することで有効化される。

新たな Scene へのプロンプト追加は `default-workspace.json` の `recommends` を編集するか、実行時に ScenePromptsEditorView から編集する (Swift コードへのハードコードは禁止)。

将来の拡張例 (参考):

| ビュー | レコメンドプロンプト例 |
|--------|----------------------|
| Filer | `"このファイルをレビューして: {path}"` |
| Preview | `"このドキュメントを翻訳して"` |
| Claude (Companion 別) | テスト担当 Companion なら `"テスト実行して"`、レビュー担当なら `"差分をレビューして"` |

---

## キー操作まとめ

| キー | 動作 |
|------|------|
| **Cmd+Enter** | レコメンドモードに入る |
| **↑ / ↓** | プロンプトを選択 |
| **← / →** | コンパニオンを選択（吹き出しが移動） |
| **Enter** | プロンプトを送信、レコメンドモード終了 |
| **Esc** | レコメンドモードをキャンセル |

---

## 状態管理

レコメンドモードの状態は `RecommendState` が持つ (@Observable)。

```swift
@Observable
final class RecommendState {
    var isActive: Bool              // レコメンドモード中か
    var selectedCompanionIndex: Int // 選択中のコンパニオン
    var selectedPromptIndex: Int    // 選択中のプロンプト
    var prompts: [String]           // 現在表示中のプロンプト一覧
}
```

### 実装コンポーネント

| 型 | ファイル | 責務 |
|---|---|---|
| `RecommendState` | `Services/Frontchannel/RecommendState.swift` | レコメンドモードのランタイム状態。`activate / deactivate` と `moveUp/Down/Left/Right` でプロンプト・コンパニオン選択をループ移動させる |
| `RecommendStore` | `Services/Frontchannel/RecommendStore.swift` | Scene ごとの `SceneConfig` をインメモリで保持する `enum` の static API。永続化は `WorkspaceSnapshotManager` 経由で `workspace.json` v7 に統合される |
| `SceneConfig` | `Services/Frontchannel/RecommendStore.swift` | Scene ごとの `prompts: [String]` と `defaultCompanionIndex: Int` を保持する Codable |
| `ScenePromptsEditorView` | `Views/Common/ScenePromptsEditorView.swift` | 各セッションの本体 View 下部に挿入される編集 UI。表示中 Scene の `prompts` 追加/削除と `defaultCompanionIndex` の切替を行う |

`SessionRegistry.view(for:)` は **Git / GitDiff 以外**の各セッション View を `VStack` で本体 + `ScenePromptsEditorView` の縦並びにラップする統一パターンを取る。GitDiff は `GitDiffSessionContainer` 側で挿入済みのため二重挿入しない。

Scene キー (`"git:prPreview"` `"git:workingChanges"` 等) は各 SessionState の `currentScene()` が文脈に応じて生成し、
`RecommendStore.prompts(for:)` で対応エントリを引く。エントリが無ければ空配列 (Cmd+Enter 無反応)。

`default-workspace.json` から流入する初期エントリが SSoT。Swift コード内にデフォルトプロンプトのハードコードは置かない (詳細は [../frontchannels/scene.md](../frontchannels/scene.md))。

---

## 境界

### Always
- Cmd+Enter はどのビューからでも起動できる
- レコメンドモード中は他のキー操作をブロックする
- 送信後に Claude セッションをアクティブタブにする

### Confirm First
- レコメンドプロンプトが空のビューでは Cmd+Enter は何もしない

### Never
- レコメンドモード中にコンパニオンの追加・編集はできない
- 複数プロンプトの一括送信はしない
