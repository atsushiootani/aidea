---
title: レコメンドモード
description: Cmd+Enter で起動するコンパニオンプロンプト選択 UI・RecommendState/RecommendStore・Scene 解決とキー操作
derived_from:
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/companions/companion.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
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

各ビュー（Tool の SessionState）がレコメンドプロンプトを提供する。

### プロトコル

```swift
protocol RecommendProvider {
    /// 現在の状態に応じたレコメンドプロンプトを返す（最大 3 つ）
    func recommendedPrompts() -> [String]
}
```

### 初期実装

| ビュー | レコメンドプロンプト |
|--------|---------------------|
| **Git** | `"コミットして"` `"プッシュして"` `"PRを作って"` |
| **その他** | （空 = レコメンドなし、Cmd+Enter は何もしない） |

将来の拡張:

| ビュー | レコメンドプロンプト例 |
|--------|----------------------|
| Filer | `"このファイルをレビューして: {path}"` |
| Preview | `"このドキュメントを翻訳して"` |
| GitDiff | `"この差分をレビューして"` |

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
| `RecommendStore` | `Services/Frontchannel/RecommendStore.swift` | `.aidea/recommends.json` への永続化 (`enum` の static API)。Scene キーから `SceneConfig` を解決 |
| `SceneConfig` | `Services/Frontchannel/RecommendStore.swift` | Scene ごとの `prompts: [String]` と `defaultCompanionIndex: Int` を保持する Codable |
| `RecommendProvider` | 各 `SessionState` で準拠 | 現在の状態に応じた最大 3 つのプロンプトを返すプロトコル |

Scene キー (`"git:prPreview"` `"git:workingChanges"` 等) は各 SessionState が文脈に応じて生成し、
`RecommendStore.resolve(scene:defaults:)` で「永続化 > デフォルト > 空」の順で解決される。

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
