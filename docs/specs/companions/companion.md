---
title: コンパニオン
description: ヘッダの 9 体アイコン・index 識別の CompanionConfig/CompanionStore 仕様・workspace.json v8 経由の永続化・起動フロー・instructions.md 外部化
derived_from:
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/sessions/ui-rules.md
  - docs/decisions/0022-companion-instructions-as-files.md
syncs_with:
  - docs/specs/companions/recommend-mode.md
  - docs/specs/aspects/persistence.md
  - docs/specs/backchannels/backchannel.md
impacts:
  - docs/specs/tools/claude.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# コンパニオン

> ヘッダに常時並ぶ **9 体固定** のアイコン。1 体が 1 つの Claude セッションに紐付き、
> 起動・フォーカス・レコメンド送信の入口になる。

[../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) が規定する「Aidea → Claude」通信の起点にあたる UI 概念。
送信メカニズム自体は frontchannel.md、レコメンド UI は [recommend-mode.md](./recommend-mode.md) を参照。

---

## 概要

- ヘッダ (`AppHeaderView`) に **9 体のコンパニオンアイコンが index 0〜8 で常に並ぶ** (個数は固定で増減できない)
- 各アイコンは `CompanionIconPresets.imageIcons` (9 枚) に対応
- 起動済み (Claude セッションと bind 済み = `sessionID != nil`) のアイコンは彩度 1.0、未起動は 0.3 でグレーアウト
- アクティブタブがそのコンパニオンの Claude セッションならアクセントカラーで枠が付く

### タップ操作

| 対象 | 動作 |
|---|---|
| アイコン (起動済み) | 紐付く Claude セッションをアクティブ化 |
| アイコン (未起動) | コンパニオンの設定で Claude セッションを起動し bind する |
| 名前ラベル | `CompanionEditView` (sheet) を開いて設定を編集 (name / icon / 「指示書を開く」ボタン) |

---

## データモデル

### `CompanionConfig`

1 体のコンパニオン設定 + 起動状態。`Models/Companion/CompanionConfig.swift` の `Codable` 構造体。

| プロパティ | 型 | 意味 |
|---|---|---|
| `index` | `Int` (0〜8) | コンパニオン識別子。ヘッダ表示順とも一致 |
| `name` | `String` | タブ・ラベルに出る表示名 |
| `icon` | `String` | アイコン名 (`Companions/companion-N` または SF Symbols 名) |
| `sessionID` | `SessionID?` | 紐付いた Claude セッション。`nil` なら未起動 |

`sessionID` は **設定** (name/icon) と同じ構造体に同居する。これは workspace.json が「現在のワークスペースのスナップショット」であり、設定とランタイム状態を一体で保存する設計に揃えている (sessions セクションも同様の構成)。

#### initialPrompt の外部ファイル化 (v8 以降)

v7 までは `CompanionConfig.initialPrompt: String` に文字列として保持していたが、v8 で削除。各コンパニオンの初期指示は `<projectRoot>/.aidea/claude/companions/<index>/instructions.md` に外部化されている (詳細は [ADR 0022](../../decisions/0022-companion-instructions-as-files.md))。

Aidea が起動時に PTY へ送る文字列は `companionIndex` から派生する固定パターン:

```
.aidea/claude/companions/<index>/instructions.md を読んで従ってね
```

これを生成・パス解決するヘルパが `Services/Companion/CompanionInstructions.swift` に集約される (`loadCommand(for:)` / `entrypointURL(projectRoot:index:)`)。

### `CompanionIconPresets`

アイコン画像の静的プリセット。9 枚のカスタム画像 (`Assets.xcassets/Companions/companion-1..9`) を定義する。小サイズ版 (`companion-N-small`) とテーマカラーも併せて保持する。

ただし **コンパニオンのデフォルト名 / icon の値そのもの** は `Aidea/Resources/default-workspace.json` (Bundle 同梱) の `companions[]` が SSoT。`CompanionIconPresets` は Assets 上のアイコンリソース対応表のみを担う。デフォルトの instructions.md 本文は `Aidea/Resources/Backchannels/companion-instructions.md` (Bundle 同梱、1 ファイルを 9 個に複製) が SSoT。

---

## ストア (`CompanionStore`)

`Services/Companion/CompanionStore.swift` の `@Observable` クラス。
9 個固定のコンパニオン配列をインメモリで保持し、永続化は [`WorkspaceSnapshotManager`](../../../Aidea/Aidea/Services/Workspace/WorkspaceSnapshotManager.swift) 経由で `.aidea/workspace.json` に書き出される (詳細は [../aspects/persistence.md](../aspects/persistence.md))。

### 状態

| プロパティ | 型 | 意味 |
|---|---|---|
| `companions` | `[CompanionConfig]` | **必ず 9 要素 (index 0〜8)**。空にしたり追加・削除はしない |

`bindings` 相当の情報は `CompanionConfig.sessionID` に統合済み。別マップは持たない。

### 主要 API

| メソッド | 役割 |
|---|---|
| `update(_ companion: CompanionConfig)` | 指定 index のコンパニオン設定を更新 (`name` / `icon` / `sessionID` を差し替え) |
| `bind(index: Int, sessionID: SessionID)` | コンパニオンと Claude セッションを紐付け (`companions[index].sessionID = sessionID`) |
| `unbind(index: Int)` | 紐付け解除 (`companions[index].sessionID = nil`) |
| `unbindSession(_ sessionID: SessionID)` | 該当 sessionID を持つ index の `sessionID` を nil にする (タブを閉じたとき用) |
| `isActive(_ index: Int) -> Bool` | `companions[index].sessionID != nil` |
| `companion(forIndex index: Int) -> CompanionConfig` | `companions[index]` (non-optional) |
| `companionName(for sessionID: SessionID) -> String?` | `SessionID` から該当コンパニオン名を逆引き (タブ表示で使用) |

`add` / `remove` / `upsert` / `createDefault(forIndex:)` は **廃止** (9 個固定で動的増減しないため)。

### 永続化

`companions` 配列は `workspace.json` v8 の `companions` フィールドに保存される (`initialPrompt` フィールドは v8 で削除済み)。詳細スキーマは [../aspects/persistence.md](../aspects/persistence.md) を参照。

旧スキーマからのマイグレーション:
- v6 → v7: UUID 識別 + `companionBindings` 別配列を icon 名 → index 逆算で統合
- v7 → v8: `companions[].initialPrompt` を削除 + 各文字列を `.aidea/claude/companions/<index>/instructions.md` に書き出し (ファイル不在時のみ。詳細は [ADR 0022](../../decisions/0022-companion-instructions-as-files.md))

---

## View 構成

| 型 | ファイル | 責務 |
|---|---|---|
| `CompanionView` | `Views/Companion/CompanionView.swift` | ヘッダに 9 体並べる本体。アイコンタップで起動/フォーカス、ラベルタップで編集 sheet を開く。レコメンドモード中は選択コンパニオンの下に `RecommendBubbleView` を表示 |
| `CompanionEditView` | `Views/Companion/CompanionEditView.swift` | 名前・アイコンを編集する sheet (`update(_:)` を呼ぶ)。「指示書を開く」ボタンで `SessionRegistry.openPreview` 経由で `.aidea/claude/companions/<index>/instructions.md` を Preview セッションとして開く (markdown view + 編集モード) |
| `RecommendBubbleView` | `Views/Companion/RecommendBubbleView.swift` | `RecommendState.prompts` を縦に並べ、選択中をアクセントカラーでハイライトする吹き出し |

---

## 起動フロー (Claude セッション未起動)

```
1. ユーザが未起動アイコン (index N) をタップ
2. companion = store.companion(forIndex: N) を取得 (必ず存在)
3. layout.nextSessionInstance(of: .claude) で新 instance 番号を採番
4. registry.createSession(tool: .claude, instance:) で Claude セッション生成
5. ClaudeSessionState.companionPrompt に CompanionInstructions.loadCommand(for: N) をセット
   = ".aidea/claude/companions/N/instructions.md を読んで従ってね"
   (ターミナル起動後に自動送信される → tools/claude.md)
6. store.bind(index: N, sessionID: session.id)
   → companions[N].sessionID が更新される
7. アクティブ pane の末尾にタブ追加しアクティブ化
```

`instructions.md` が不在のまま起動した場合の挙動は `BackchannelSetup` の責務 (新規プロジェクト初回セットアップ時にコピー)。詳細は [../backchannels/backchannel.md](../backchannels/backchannel.md) を参照。

---

## 起動フロー (スナップショット復元時)

Aidea 起動時、`workspace.json` から Claude タブが復元されるケースの挙動:

```
1. AideaApp.init() が WorkspaceSnapshotManager.load(projectRoot:) で
   workspace.json を読み込む
   - 旧版なら自動マイグレーション (v6 → v7 で UUID → index 化、bindings 統合)
   - workspace.json 不在なら Bundle 同梱の default-workspace.json を使う
2. WorkspaceSnapshotManager.apply() が同期的に以下を実行:
   - レイアウトツリー復元 (タブ構成のみ、セッション実体は未生成)
   - snapshot.companions を CompanionStore.companions にセット (9 要素)
   - snapshot.recommends を RecommendStore にセット
3. 同じ apply() 内で sessionID が non-nil なコンパニオンに対して
   companionPrompt 再注入:
   - companions を走査し、sessionID != nil な index について
   - registry.ensureSession(for: sessionID) で ClaudeSessionState を生成
     (PTY/terminalView は引き続き lazy)
   - state.companionPrompt = CompanionInstructions.loadCommand(for: index) をセット
     ( = ".aidea/claude/companions/<index>/instructions.md を読んで従ってね")
   - state.companionIndex = index もセット (Scene 識別子 claude:<index> 解決用)
4. ユーザがタブをアクティブ化 → terminalView 生成 → 自動起動シーケンス
   → companionPrompt が送信される
```

この再注入がないと、復元された Claude セッションは `companionPrompt == nil` のままで
`claude` CLI は起動するが initialPrompt が送られない (Issue #69 の挙動)。

---

## 関連ドキュメント

- [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) — 送信メカニズム (PTY `send(txt:)`)
- [recommend-mode.md](./recommend-mode.md) — Cmd+Enter によるレコメンド選択 UI
- [../tools/claude.md](../tools/claude.md) — Claude セッション側の挙動
- [../aspects/persistence.md](../aspects/persistence.md) — `workspace.json` v7 保存・Bundle テンプレ
- [../sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) — SessionID / 5 概念
