---
title: コンパニオン
description: ヘッダの 9 体アイコン・index 識別の CompanionConfig/CompanionStore 仕様・workspace.json v8 経由の永続化・起動フロー・instructions.md 外部化
derived_from:
  - docs/specs/frontchannels/frontchannel.md
  - docs/specs/sessions/ui-rules.md
  - docs/decisions/0022-companion-instructions-as-files.md
syncs_with:
  - docs/specs/companions/recommend-mode.md
  - docs/specs/companions/speech-history.md
  - docs/specs/companions/agent-definition.md
  - docs/specs/aspects/persistence.md
  - docs/specs/aspects/view-hierarchy.md
  - docs/specs/backchannels/backchannel.md
  - docs/specs/backchannels/companion-roster.md
  - docs/specs/backchannels/voicevox.md
  - docs/specs/sessions/claude.md
  - docs/specs/tools/claude.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-06
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

Aidea が起動時に PTY へ送る文字列は `agent.md` の有無によって切り替わる (ADR 0026):

- **`agent.md` あり**: `.aidea/claude/companions/<index>/agent.md を読んで、その定義に従ってエージェントとして動いてね`
- **`agent.md` なし**: `.aidea/claude/companions/<index>/instructions.md を読んで従ってね`

パス解決と起動コマンド生成は `CompanionInstructions` サービスに集約される。
詳細は [agent-definition.md](./agent-definition.md) を参照。

### `CompanionIconPresets`

アイコン画像の静的プリセット。各コンパニオンに対し以下 4 種のバリアントを `Assets.xcassets/Companions/` に持つ。

| サフィックス | 用途 | 画像名例 |
|---|---|---|
| (なし) | 通常表情 (normal) | `companion-1.jpg` |
| `-small` | 小サイズ版 (リスト等) | `companion-1-small.jpg` |
| `-smile` | 笑顔表情 (読み上げ中) | `companion-1-smile.jpg` |
| `-thinking` | 考え中表情 (Claude 実行中) | `companion-1-thinking.jpg` |

`-smile` / `-thinking` は issue #45 で追加された表情セット。読み上げ中と実行中の表示切替に使う (詳細は後述の「表情・状態表示」節)。

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
| `update(_ companion: CompanionConfig)` | 指定 index のコンパニオン設定を更新 (`name` / `icon` / `sessionID` を差し替え)。`name` を変更する経路 (主に `CompanionEditView` の OK ハンドラ) では呼び出し側で直後に `CompanionRosterWriter.writeRoster(...)` を呼び、`.aidea/claude/aidea.md` のコンパニオン名簿セクションを更新する ([companion-roster.md](../backchannels/companion-roster.md)) |
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
5. ClaudeSessionState.companionPrompt に CompanionInstructions.startupCommand(for: N, projectRoot:) をセット
   = agent.md が存在すれば ".aidea/claude/companions/N/agent.md を読んで、その定義に従ってエージェントとして動いてね"
   = agent.md がなければ ".aidea/claude/companions/N/instructions.md を読んで従ってね" (ADR 0022/0026)
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
   - companionPrompt に起動コマンドをセット
     (agent.md が存在すればエージェント定義読み込みコマンド、なければ instructions.md 読み込みコマンド)
   - companionIndex をセット (Scene 識別子 claude:<index> 解決用)
4. ユーザがタブをアクティブ化 → terminalView 生成 → 自動起動シーケンス
   → companionPrompt が送信される
```

この再注入がないと、復元された Claude セッションは `companionPrompt == nil` のままで
`claude` CLI は起動するが initialPrompt が送られない (Issue #69 の挙動)。

---

## 表情・状態表示 (issue #45)

Companion アイコンは 4 つの状態を持ち、ベース画像 (normal / smile / thinking) と
SF Symbol オーバーレイの組み合わせで表現する。

### 状態と表示

| 状態 | 発火条件 | ベース画像 | オーバーレイ | アイコン暗転 |
|---|---|---|---|---|
| **未起動** | `companion.sessionID == nil` | `companion-N-small` (thumbnail) | なし | 彩度 0.3 / 不透明度 0.5 |
| **アイドル** | セッション起動済み・busy でない・読み上げ中でない | `companion-N-small` (thumbnail) | なし | なし |
| **実行中** | `ClaudeSessionState.isBusy == true` | `companion-N-thinking` | `ellipsis.bubble` (濃いグレー) | なし |
| **読み上げ中** | `SpeechQueue.currentlySpeakingIndex == N` | `companion-N-smile` | `heart.fill` (pink) | なし |

### 優先順位

同時に複数の条件が成立した場合、**読み上げ中 > 実行中 > アイドル > 未起動** の順で上位を採用する。
通常のフローでは「プロンプト送信 → 実行中 → (要約 speech 書き出しで) 読み上げ中」と遷移するため、実行中と読み上げ中が長時間同時成立することはないが、両方成立した瞬間は読み上げ中を優先する。

### オーバーレイの詳細

- **位置**: アイコン右上隅 (コーナーバッジ風)
- **サイズ**: アイコン幅の約 1/3 (60x60 アイコンに対して 18pt)
- **色**:
  - `heart.fill`: pink (`Color.pink`)
  - `ellipsis.bubble`: 濃いグレー (`Color(white: 0.25)`。dark/light mode に依らず同じ視認性を得るため primary に従わず固定)
- **背景**: SF Symbol の後ろに半透明の白角丸 (`RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.6))`) を敷く。アイコン画像のコントラストに関係なく記号が沈まないよう視認性を確保するため
- **描画順**: ベース画像の上にオーバーレイする (枠線・クリップ形状より前)

### 未起動時の挙動

本文中「アイコンは暗くなっている」= 既存実装の `saturation(0.3) + opacity(0.5)` を踏襲する (彩度と不透明度の両方を下げる)。この暗転は未起動状態でのみ適用し、他の 3 状態では通常表示 (`saturation(1.0) + opacity(1.0)`)。

### 依存する状態源

| 状態 | 参照する `@Observable` | 新規/既存 |
|---|---|---|
| `sessionID == nil` | `CompanionStore.companions[N].sessionID` | 既存 |
| `isBusy` | `ClaudeSessionState.isBusy` | **新規** (issue #45 で追加) |
| `isSpeaking` | `ClaudeSessionState.isSpeaking` (facade) → `SpeechQueue.currentlySpeakingIndex` | **新規** (issue #45 で追加、voicevox.md の将来拡張枠を具体化) |

- `ClaudeSessionState.isBusy`: PTY 出力が続いている間 true。静止を検知したら false。詳細は [../tools/claude.md](../tools/claude.md) を参照
- `ClaudeSessionState.isSpeaking`: `SpeechQueue.currentlySpeakingIndex == companionIndex` を返す computed facade。`CompanionView` は `isBusy` と対称に ClaudeSessionState から read し、SpeechQueue の Observable tracking が自動で伝播する。詳細は [../backchannels/voicevox.md](../backchannels/voicevox.md) を参照

### 実装箇所

| コンポーネント | 役割 |
|---|---|
| `CompanionView.companionIcon(_:)` | 状態を判定してベース画像を差し替え + オーバーレイ描画 |
| `CompanionIconPresets` | `thumbnailIcon(for:)` に加えて `smileIcon(for:)` / `thinkingIcon(for:)` を追加 |

### 境界

- **Always**: 状態は `@Observable` の変化に駆動される Pure SwiftUI (タイマー polling しない)。優先順位判定は `CompanionView` の 1 箇所に集約
- **Never**: 表情切替のために companion の永続状態 (`workspace.json`) を書き換えない。`isBusy` / `currentlySpeakingIndex` はランタイム情報のみ

---

## 関連ドキュメント

- [../frontchannels/frontchannel.md](../frontchannels/frontchannel.md) — 送信メカニズム (PTY `send(txt:)`)
- [agent-definition.md](./agent-definition.md) — `agent.md` によるエージェント定義仕様 (ADR 0026)
- [recommend-mode.md](./recommend-mode.md) — Cmd+Enter によるレコメンド選択 UI
- [speech-history.md](./speech-history.md) — speech 履歴ビュー (CompanionEditView から開く)
- [../backchannels/handoff.md](../backchannels/handoff.md) — Companion 間ハンドオフ ([ADR 0023](../../decisions/0023-companion-handoff.md))
- [../backchannels/companion-roster.md](../backchannels/companion-roster.md) — `aidea.md` 内のコンパニオン名簿自動同期
- [../tools/claude.md](../tools/claude.md) — Claude セッション側の挙動
- [../aspects/persistence.md](../aspects/persistence.md) — `workspace.json` v7 保存・Bundle テンプレ
- [../sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) — SessionID / 5 概念
