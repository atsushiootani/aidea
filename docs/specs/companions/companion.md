---
title: コンパニオン
description: ヘッダの 8 体アイコン・CompanionConfig/CompanionStore の仕様・companions.json 永続化・起動フロー
derived_from:
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/sessions/ui-rules.md
syncs_with:
  - docs/specs/companions/recommend-mode.md
  - docs/specs/tools/claude.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
---

# コンパニオン

> ヘッダに常時並ぶ 8 体のアイコン。1 体が 1 つの Claude セッションに紐付き、
> 起動・フォーカス・レコメンド送信の入口になる。

[../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) が規定する「Aidea → Claude」通信の起点にあたる UI 概念。
送信メカニズム自体は frontchannel.md、レコメンド UI は [recommend-mode.md](./recommend-mode.md) を参照。

---

## 概要

- ヘッダ (`AppHeaderView`) に **常に 8 体のコンパニオンアイコンが並ぶ**
- 各アイコンは `CompanionIconPresets.imageIcons` (8 枚) に対応
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
| `autoLaunch` | `Bool` | Aidea 起動時に自動で Claude セッションを開始するか |

### `CompanionIconPresets`

アイコン画像の静的プリセット。8 枚のカスタム画像 (`Assets.xcassets/Companions/companion-0..7`) を定義する。

---

## ストア (`CompanionStore`)

`Services/Companion/CompanionStore.swift` の `@Observable` クラス。
設定と紐付けを保持し、`.aidea/companions.json` に永続化する。

### 状態

| プロパティ | 型 | 意味 |
|---|---|---|
| `companions` | `[CompanionConfig]` | 登録済みコンパニオンの配列 |
| `activeSessionMap` | `[UUID: SessionID]` | コンパニオン ID → 紐付いた Claude セッション |

### 主要 API

| メソッド | 役割 |
|---|---|
| `load(projectRoot:)` | `.aidea/companions.json` から読込 (新旧フォーマット両対応でマイグレーション) |
| `save()` | `companions` + `bindings` を JSON で書き戻し |
| `add / update / remove / upsert` | コンパニオン CRUD。すべて自動保存 |
| `bind(companionID:sessionID:)` | コンパニオンと Claude セッションを紐付け |
| `unbind(companionID:)` / `unbindSession(_:)` | 紐付け解除 (タブを閉じたときは後者) |
| `isActive(_:)` | セッション起動中かを返す |
| `companion(forIndex:)` | アイコンインデックスから登録済みコンパニオンを検索 |
| `createDefault(forIndex:)` | アイコンインデックスから未登録のデフォルト設定を生成 |
| `companionName(for:)` | `SessionID` からコンパニオン名を逆引き (タブ表示で使用) |
| `autoLaunchCompanions` | 起動時 Auto Launch 対象一覧 |

### 永続化フォーマット

```json
{
  "companions": [
    { "id": "...", "name": "...", "icon": "Companions/companion-0",
      "initialPrompt": "...", "autoLaunch": false }
  ],
  "bindings": [
    { "companionID": "...", "sessionID": { "tool": "claude", "instance": 0 } }
  ]
}
```

旧フォーマット (`[CompanionConfig]` 直列) から読めた場合は自動マイグレーション。

---

## View 構成

| 型 | ファイル | 責務 |
|---|---|---|
| `CompanionView` | `Views/Companion/CompanionView.swift` | ヘッダに 8 体並べる本体。アイコンタップで起動/フォーカス、ラベルタップで編集 sheet を開く。レコメンドモード中は選択コンパニオンの下に `RecommendBubbleView` を表示 |
| `CompanionEditView` | `Views/Companion/CompanionEditView.swift` | 名前・initialPrompt・autoLaunch を編集する sheet |
| `RecommendBubbleView` | `Views/Companion/RecommendBubbleView.swift` | `RecommendState.prompts` を縦に並べ、選択中をアクセントカラーでハイライトする吹き出し |

---

## 起動フロー (未登録コンパニオン)

```
1. ユーザが未起動アイコンをタップ
2. CompanionStore.createDefault(forIndex:) でデフォルト設定を生成
   - name: "Companion N+1"
   - icon: プリセット画像
   - initialPrompt: ".aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね"
3. store に未登録なら add して永続化
4. layout.nextSessionInstance(of: .claude) で新 instance 番号を採番
5. registry.createSession(tool: .claude, instance:) で Claude セッション生成
6. ClaudeSessionState.companionPrompt に initialPrompt をセット
   (ターミナル起動後に自動送信される → tools/claude.md)
7. store.bind(companionID:sessionID:)
8. アクティブ pane の末尾にタブ追加しアクティブ化
```

---

## 関連ドキュメント

- [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) — 送信メカニズム (PTY `send(txt:)`)
- [recommend-mode.md](./recommend-mode.md) — Cmd+Enter によるレコメンド選択 UI
- [../tools/claude.md](../tools/claude.md) — Claude セッション側の挙動
- [../aspects/persistence.md](../aspects/persistence.md) — `.aidea/companions.json` のタイミング
- [../sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) — SessionID / 5 概念
