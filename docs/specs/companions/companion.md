---
title: コンパニオン
description: ヘッダの 9 体アイコン・CompanionConfig/CompanionStore の仕様・workspace.json v3 経由の永続化・起動フロー
derived_from:
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/sessions/ui-rules.md
syncs_with:
  - docs/specs/companions/recommend-mode.md
  - docs/specs/aspects/persistence.md
impacts:
  - docs/specs/tools/claude.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-20
---

# コンパニオン

> ヘッダに常時並ぶ 9 体のアイコン。1 体が 1 つの Claude セッションに紐付き、
> 起動・フォーカス・レコメンド送信の入口になる。

[../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) が規定する「Aidea → Claude」通信の起点にあたる UI 概念。
送信メカニズム自体は frontchannel.md、レコメンド UI は [recommend-mode.md](./recommend-mode.md) を参照。

---

## 概要

- ヘッダ (`AppHeaderView`) に **常に 9 体のコンパニオンアイコンが並ぶ**
- 各アイコンは `CompanionIconPresets.imageIcons` (9 枚) に対応
- 起動済み (Claude セッションと bind 済み) のアイコンは彩度 1.0、未起動は 0.3 でグレーアウト
- アクティブタブがそのコンパニオンの Claude セッションならアクセントカラーで枠が付く

### タップ操作

| 対象 | 動作 |
|---|---|
| アイコン (起動済み) | 紐付く Claude セッションをアクティブ化 |
| アイコン (未起動) | デフォルト設定で Claude セッションを起動し bind する |
| 名前ラベル | `CompanionEditView` (sheet) を開いて設定を編集 |

---

## データモデル

### `CompanionConfig`

1 体のコンパニオン設定。`Models/Companion/CompanionConfig.swift` の `Codable` 構造体。

| プロパティ | 型 | 意味 |
|---|---|---|
| `id` | `UUID` | コンパニオン識別子 (bind の鍵) |
| `name` | `String` | タブ・ラベルに出る表示名 |
| `icon` | `String` | アイコン名 (`Companions/companion-N` または SF Symbols 名) |
| `initialPrompt` | `String` | Claude 起動直後に送信する初期プロンプト |

### `CompanionIconPresets`

アイコン画像の静的プリセット。9 枚のカスタム画像 (`Assets.xcassets/Companions/companion-1..9`) を定義する。小サイズ版 (`companion-N-small`) とテーマカラーも併せて保持する。

---

## ストア (`CompanionStore`)

`Services/Companion/CompanionStore.swift` の `@Observable` クラス。
設定と紐付けをインメモリで保持し、永続化は [`WorkspaceSnapshotManager`](../../../Aidea/Aidea/Services/Workspace/WorkspaceSnapshotManager.swift) 経由で `.aidea/workspace.json` に書き出される (詳細は [../aspects/persistence.md](../aspects/persistence.md))。

### 状態

| プロパティ | 型 | 意味 |
|---|---|---|
| `companions` | `[CompanionConfig]` | 登録済みコンパニオンの配列 |
| `activeSessionMap` | `[UUID: SessionID]` | コンパニオン ID → 紐付いた Claude セッション |

### 主要 API

| メソッド | 役割 |
|---|---|
| `add / update / remove / upsert` | コンパニオン CRUD (インメモリのみ更新。保存は workspace.json 終了時) |
| `bind(companionID:sessionID:)` | コンパニオンと Claude セッションを紐付け |
| `unbind(companionID:)` / `unbindSession(_:)` | 紐付け解除 (タブを閉じたときは後者) |
| `isActive(_:)` | セッション起動中かを返す |
| `companion(forIndex:)` | アイコンインデックスから登録済みコンパニオンを検索 |
| `createDefault(forIndex:)` | アイコンインデックスから未登録のデフォルト設定を生成 |
| `companionName(for:)` | `SessionID` からコンパニオン名を逆引き (タブ表示で使用) |

### 永続化

`CompanionConfig` の配列と `activeSessionMap` (bindings) は `workspace.json` v3 の `companions` / `companionBindings` フィールドに保存される。旧 `.aidea/companions.json` が存在する場合は起動時に `WorkspaceSnapshotManager` が自動でマイグレーションして削除する。詳細スキーマは [../aspects/persistence.md](../aspects/persistence.md) を参照。

---

## View 構成

| 型 | ファイル | 責務 |
|---|---|---|
| `CompanionView` | `Views/Companion/CompanionView.swift` | ヘッダに 9 体並べる本体。アイコンタップで起動/フォーカス、ラベルタップで編集 sheet を開く。レコメンドモード中は選択コンパニオンの下に `RecommendBubbleView` を表示 |
| `CompanionEditView` | `Views/Companion/CompanionEditView.swift` | 名前・initialPrompt を編集する sheet |
| `RecommendBubbleView` | `Views/Companion/RecommendBubbleView.swift` | `RecommendState.prompts` を縦に並べ、選択中をアクセントカラーでハイライトする吹き出し |

---

## 起動フロー (未登録コンパニオン)

```
1. ユーザが未起動アイコンをタップ
2. CompanionStore.createDefault(forIndex:) でデフォルト設定を生成
   - name: "Companion N+1"
   - icon: プリセット画像
   - initialPrompt: ".aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね"
3. store に未登録なら add (インメモリ反映のみ、永続化は workspace.json 終了時)
4. layout.nextSessionInstance(of: .claude) で新 instance 番号を採番
5. registry.createSession(tool: .claude, instance:) で Claude セッション生成
6. ClaudeSessionState.companionPrompt に initialPrompt をセット
   (ターミナル起動後に自動送信される → tools/claude.md)
7. store.bind(companionID:sessionID:)
8. アクティブ pane の末尾にタブ追加しアクティブ化
```

---

## 起動フロー (スナップショット復元時)

Aidea 起動時、`workspace.json` から Claude タブが復元されるケースの挙動:

```
1. AideaApp.init() が WorkspaceSnapshotManager.load(projectRoot:) で
   workspace.json を読み込む (v2 の場合は旧 companions.json / recommends.json を
   統合した v3 相当のスナップショットに自動マイグレーション)
2. WorkspaceSnapshotManager.apply() が同期的に以下を実行:
   - レイアウトツリー復元 (タブ構成のみ、セッション実体は未生成)
   - snapshot.companions を CompanionStore.companions にセット
   - snapshot.companionBindings を CompanionStore.activeSessionMap にセット
   - snapshot.recommends を RecommendStore にセット
3. 同じ apply() 内で bind 済みセッションへの companionPrompt 再注入:
   - activeSessionMap を走査し、各 sessionID について
   - registry.ensureSession(for: sessionID) で ClaudeSessionState を生成
     (PTY/terminalView は引き続き lazy)
   - 対応する CompanionConfig.initialPrompt を state.companionPrompt にセット
4. ユーザがタブをアクティブ化 → terminalView 生成 → 自動起動シーケンス
   → initialPrompt が送信される
```

この再注入がないと、復元された Claude セッションは `companionPrompt == nil` のままで
`claude` CLI は起動するが initialPrompt が送られない (Issue #69 の挙動)。

---

## 関連ドキュメント

- [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) — 送信メカニズム (PTY `send(txt:)`)
- [recommend-mode.md](./recommend-mode.md) — Cmd+Enter によるレコメンド選択 UI
- [../tools/claude.md](../tools/claude.md) — Claude セッション側の挙動
- [../aspects/persistence.md](../aspects/persistence.md) — `workspace.json` v3 保存のタイミング
- [../sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) — SessionID / 5 概念
