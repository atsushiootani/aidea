---
title: Persistence (データ永続化)
description: UserDefaults / Keychain / .aidea/ のデータ永続化仕様を機能群横断で集約
derived_from:
  - docs/specs/architecture.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/backchannels/voicevox.md
  - docs/specs/frontchannels/scene.md
  - docs/specs/companions/companion.md
  - docs/specs/companions/recommend-mode.md
  - docs/specs/sessions/filer.md
  - docs/specs/sessions/kit.md
  - docs/specs/sessions/preview.md
  - docs/specs/sessions/web.md
  - docs/specs/tools/preview.md
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/aspects/README.md
last_updated: 2026-04-20
---

# Persistence (データ永続化)

Aidea が **どのデータをどこに、どのタイミングで保存するか** の仕様。

保存先は大きく 3 種類:

1. **UserDefaults** — アプリ全体のユーザ設定 (最小限)
2. **Keychain** — 機密情報 (API キー)
3. **`<projectRoot>/.aidea/`** — プロジェクト固有の状態・リソース・通信データ (メイン)

`~/Library/Application Support/Aidea/` は **現時点では使用していない**。プロジェクト固有の情報は `.aidea/` 配下に集約することで、プロジェクトをまたいだ干渉を防いでいる。

---

## 保存先ごとのデータ

### UserDefaults (アプリ全体設定)

| キー | 型 | 用途 |
|---|---|---|
| `aidea.projectRoot` | String | 最後に開いていたプロジェクトのパス。起動時復元用 |

管理: `Services/Workspace/WorkspaceState.swift`
読込: `init()` (起動時)、書込: `setProjectRoot(_:)` (ディレクトリ変更時)

### Keychain (機密情報)

| サービス | 用途 |
|---|---|
| `com.aidea.anthropic-api-key` | Anthropic API キー (翻訳機能で使用) |

管理: `Utilities/KeychainHelper.swift` (`save` / `load` / `delete`)
利用: `Services/Translation/ClaudeTranslator.swift`

### `<projectRoot>/.aidea/` (プロジェクト固有)

```
<projectRoot>/.aidea/
├── workspace.json        # レイアウト・Session 状態・コンパニオン・レコメンドの統合スナップショット (v4)
├── backchannels/         # Claude からのメッセージ受信ディレクトリ
│   └── speech-*.txt      # 読み上げ対象テキスト (消費後に削除)
├── claude/               # Claude 起動時に読ませるリソース
│   ├── aidea.md          # Backchannel 機能の指示書
│   └── speech.md         # speech 機能の指示書 (Bundle からコピー)
└── ja/                   # 英語ドキュメントの日本語翻訳キャッシュ
    └── <相対パス>/<filename>
```

- `projectRoot` が変わるたびに `ensureAideaDirectory()` が `.aidea/` と `.aidea/ja/` を生成し、**プロジェクトの `.gitignore` に `.aidea/` を自動追記** する
- `.aidea/claude/*.md` と `.aidea/backchannels/` は初回のみ `BackchannelSetup.setup()` が作成・複製する
- v2 以前の旧ファイル `.aidea/companions.json` / `.aidea/recommends.json` は起動時に `WorkspaceSnapshotManager` が `workspace.json` v3 に統合して自動削除する

---

## ファイル詳細

### `workspace.json` (レイアウト・Session 状態・コンパニオン・レコメンド統合)

- **管理**: `Services/Workspace/WorkspaceSnapshotManager.swift`
- **フォーマット**: JSON (`version: 4`)
- **保存内容**:
  - レイアウトツリー (ノード ID / 分割軸 / ペイン構造)
  - 各 Tab の状態:
    - Preview: `url` + `title`
    - Web: `url`
    - Filer: `expandedURLs` + `excludeRules`
    - Kit: `expandedSections` + `expandedGroups`
  - アクティブペイン ID
  - `companions`: `[{id, name, icon, initialPrompt}]` (CompanionStore から収集)
  - `companionBindings`: `[{companionID, sessionID}]` (activeSessionMap から収集)
  - `recommends`: `{scene: {prompts: [String], defaultCompanionIndex: Int}}` (RecommendStore から収集)
- **読込**: `AideaApp.init()` で `WorkspaceSnapshotManager.load()` → `apply()` を呼び出し、レイアウト/コンパニオン/レコメンドをまとめて復元
- **保存**: アプリ終了時 / バックグラウンド化時に一括保存 (`AideaApp.registerTerminationObserver()`)
- **v2 → v3 マイグレーション**: 読込時に `companions == nil` なら旧 `.aidea/companions.json` / `.aidea/recommends.json` を読み取って統合し、旧ファイルを削除する
- **v3 → v4 マイグレーション**: 読込時に Filer Tab の `excludeRules == nil` ならデフォルト除外ルール ([../tools/filer.md#デフォルト除外ルール](../tools/filer.md#デフォルト除外ルール)) を設定する

### `.aidea/ja/<path>` (翻訳キャッシュ)

- **管理**: `Services/Translation/TranslationCache.swift`
- **フォーマット**: Markdown (翻訳結果そのまま)
- **鮮度判定**: 元ファイルとの mtime 比較で再翻訳要否を決める

---

## Backchannel 通信

Claude → Aidea 方向の通信は**ファイル経由**で行う。

### フロー

```
1. Claude 起動時
   └─ コンパニオンの initialPrompt が .aidea/claude/aidea.md と speech.md を読ませる

2. Claude がレスポンス末尾で以下を実行:
   └─ .aidea/backchannels/speech-{timestamp}.txt に要約テキストを書き出す
        (100 文字以内の日本語、英単語はカタカナ化、記号省略)

3. SpeechWatcher (FSEvents) が .aidea/backchannels/ を監視
   ├─ speech.txt または speech-*.txt を検知
   ├─ コンテンツをコールバックで SpeechState に渡す
   └─ 処理後にファイルを削除

4. SpeechState が VOICEVOX Service (localhost:50021) に投げて読み上げ
```

### 関連クラス

| ファイル | 役割 |
|---|---|
| `Services/Backchannel/BackchannelSetup.swift` | Bundle → `.aidea/claude/` の初期コピー |
| `Services/Backchannel/Speech/SpeechWatcher.swift` | `.aidea/backchannels/` の FSEvents 監視 |
| `Services/Backchannel/Speech/SpeechState.swift` | Speech 状態管理と VOICEVOX 連携 |

詳細は [../backchannels/](../backchannels/README.md) を参照。

---

## 永続化タイミング一覧

| タイミング | 対象 | 呼び出し元 |
|---|---|---|
| 起動時 | UserDefaults → `projectRoot` 復元 | `WorkspaceState.init()` |
| 起動時 | `workspace.json` 読込・レイアウト / コンパニオン / レコメンド一括復元 → bind 済みセッションへの `companionPrompt` 再注入 | `AideaApp.init()` → `WorkspaceSnapshotManager.apply()` |
| projectRoot 変更時 | `.aidea/` 生成 + `.gitignore` 追記 + Backchannel 再初期化 | `WorkspaceState.setProjectRoot()` |
| Companion / Recommend 変更時 | インメモリのみ更新 (即座保存しない) | `CompanionStore` / `RecommendStore` |
| Claude からメッセージ受信時 | `speech-*.txt` → 読み上げ → ファイル削除 | `SpeechWatcher` |
| 終了時 / バックグラウンド化時 | `workspace.json` (レイアウト + コンパニオン + レコメンド統合) 保存 | `AideaApp.registerTerminationObserver()` |

---

## 設計ポリシー

- **プロジェクト固有は `.aidea/`**: 複数プロジェクトをまたいだ干渉を避けるため、プロジェクト固有の状態・リソース・通信データはすべて `<projectRoot>/.aidea/` に集約する
- **グローバル設定は UserDefaults**: プロジェクトに依存しないユーザ設定のみ
- **機密情報は Keychain**: API キー等は macOS 標準の Keychain に委譲
- **`.aidea/` は git 管理外**: Aidea が自動で `.gitignore` に追加する (プロジェクト側で除外する手間を省く)
- **ファイルフォーマットは JSON / Markdown / Plain Text**: バイナリは使わず、直接編集・diff 可能にする

---

## 関連ドキュメント

- [../architecture.md](../architecture.md) — 全体のアーキテクチャ
- [../backchannels/](../backchannels/README.md) — 通信チャネル (Claude → Aidea) の詳細
- [../frontchannels/](../frontchannels/README.md) — 通信チャネル (Aidea → Claude) の詳細
- [../sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) — Session 概念
