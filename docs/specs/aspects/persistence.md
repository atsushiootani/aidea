---
title: Persistence (データ永続化)
description: UserDefaults / Keychain / Bundle Resources / .aidea/ / quickmemo/todo/ のデータ永続化と初期値テンプレ仕様を機能群横断で集約
derived_from:
  - docs/specs/architecture.md
  - docs/decisions/0022-companion-instructions-as-files.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
  - docs/decisions/0026-use-git-info-exclude-instead-of-gitignore.md
syncs_with:
  - docs/specs/backchannels/backchannel.md
  - docs/specs/backchannels/voicevox.md
  - docs/specs/backchannels/handoff.md
  - docs/specs/backchannels/output.md
  - docs/specs/backchannels/context.md
  - docs/specs/backchannels/companion-roster.md
  - docs/specs/frontchannels/scene.md
  - docs/specs/companions/companion.md
  - docs/specs/companions/recommend-mode.md
  - docs/specs/sessions/filer.md
  - docs/specs/sessions/kit.md
  - docs/specs/sessions/preview.md
  - docs/specs/sessions/web.md
  - docs/specs/sessions/active-session.md
  - docs/specs/tools/preview.md
  - docs/specs/window/active-session-switcher.md
  - docs/specs/skills/concier-schedule-voice.md
  - docs/specs/widgets/quick-memo.md
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/aspects/README.md
last_updated: 2026-05-08
---

# Persistence (データ永続化)

Aidea が **どのデータをどこに、どのタイミングで保存するか** の仕様。

保存先は大きく 5 種類:

1. **UserDefaults** — アプリ全体のユーザ設定 (最小限)
2. **Keychain** — 機密情報 (API キー)
3. **Bundle Resources** — アプリ同梱の初期値テンプレ・指示書 (読み取り専用)
4. **`<projectRoot>/.aidea/`** — プロジェクト固有の状態・リソース・通信データ (メイン)
5. **`<projectRoot>/quickmemo/todo/`** — クイックメモの保存先 (`.aidea/` 外のプロジェクト直下)

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
| `com.aidea.anthropic-api-key` | Anthropic API キー (翻訳・ディレクトリ概要生成機能で使用) |

管理: `Utilities/KeychainHelper.swift` (`save` / `load` / `delete`)
利用: `Services/Translation/ClaudeTranslator.swift` / `Services/Filer/DirectorySummaryService.swift`

### Bundle Resources (`Aidea/Resources/`)

アプリバンドルに同梱する **初期値テンプレ・指示書**。Xcode の `PBXFileSystemSynchronizedRootGroup` (Xcode 16) により `Aidea/Resources/` 配下は自動でビルドに含まれる (pbxproj 編集不要)。

| パス | 用途 |
|---|---|
| `default-workspace.json` | `<projectRoot>/.aidea/workspace.json` の初期テンプレ (ハードコード排除の SSoT) |
| `Backchannels/aidea.md` | Backchannel 機能の指示書。`BackchannelSetup` が `.aidea/claude/` にコピー |
| `Backchannels/speech.md` | speech 機能の指示書 (同上) |
| `Backchannels/handoff.md` | Companion 間ハンドオフ機能の指示書 (同上)。詳細は [../backchannels/handoff.md](../backchannels/handoff.md) |
| `Backchannels/output.md` | output 記録機能の指示書 (同上)。詳細は [../backchannels/output.md](../backchannels/output.md) |
| `Backchannels/companion-instructions.md` | コンパニオン指示書 (`instructions.md`) のデフォルトテンプレ。`BackchannelSetup` が 9 個に複製して `.aidea/claude/companions/<0..8>/instructions.md` に配置 (既存ファイルは上書きしない) |
| `Backchannels/schedule-voice.md` | スケジュールリマインド機能の指示書。`BackchannelSetup` が `.aidea/claude/` にコピー |
| `Backchannels/concier-schedule.yaml` | スケジュールリマインド設定テンプレ。`BackchannelSetup` が `.aidea/config/concier-schedule.yaml` に配置 (既存ファイルは上書きしない) |

**設計ポリシー**: ハードコードしがちなデフォルト値 (初期レイアウト・コンパニオン定義・レコメンドプロンプト等) は Swift コード側に二重管理せず、Bundle 同梱の JSON / Markdown を **唯一のソース** とする。

### `<projectRoot>/.aidea/` (プロジェクト固有)

```
<projectRoot>/.aidea/
├── workspace.json            # レイアウト・Session 状態・コンパニオン・レコメンド・履歴の統合スナップショット (v8)
├── backchannels/             # Claude からのメッセージ受信ディレクトリ (ADR 0024: Companion 別に分離し履歴保全)
│   ├── 0/                    # Companion 0 のメッセージ置き場
│   │   ├── speech-*.txt      # 読み上げ対象テキスト (処理後も残す / 履歴)
│   │   ├── handoff-*.json    # Companion 0 が送信したハンドオフ (処理後も残す、[../backchannels/handoff.md](../backchannels/handoff.md))
│   │   ├── output-*.txt      # レスポンス全文の出力記録 (処理後も残す / 履歴、[../backchannels/output.md](../backchannels/output.md))
│   │   └── context.txt       # セッション間記憶保持用コンテキスト (上書き更新、[../backchannels/context.md](../backchannels/context.md))
│   ├── 1/                    # Companion 1
│   │   └── ...
│   └── ...                   # 0..8 (必要に応じて Claude が mkdir で作成)
├── claude/                   # Claude 起動時に読ませるリソース
│   ├── aidea.md              # Backchannel 機能の指示書 (共有)
│   ├── speech.md             # speech 機能の指示書 (共有)
│   ├── handoff.md            # Companion 間ハンドオフの指示書 (共有)
│   ├── output.md             # output 記録機能の指示書 (共有)
│   ├── schedule-voice.md     # スケジュールリマインド機能の指示書 (共有)
│   └── companions/           # コンパニオン別の指示書 (v8 新設)
│       ├── 0/
│       │   ├── instructions.md  # ← Aidea が起動時に "読んで" と指示するエントリーポイント
│       │   └── *.md             # (任意) 段階的開示の参照先
│       ├── 1/instructions.md
│       └── ...                  # 0…8 の 9 ディレクトリ固定
├── config/                   # 機能別設定ファイル (ユーザ編集可)
│   └── concier-schedule.yaml # スケジュールリマインドの設定 (初回起動時に Bundle テンプレからコピー)
├── state/                    # ランタイム状態 (Claude が自律管理)
│   └── concier-notified.json # スケジュールリマインドの既読フラグ
└── ja/                       # 英語ドキュメントの日本語翻訳キャッシュ
    └── <相対パス>/<filename>
```

- `projectRoot` が変わるたびに `ensureAideaDirectory()` が `.aidea/` と `.aidea/ja/` を生成し、**`.git/info/exclude` に `.aidea/` を自動追記** する (共有 `.gitignore` は触らない、ADR 0026)
- `.aidea/claude/*.md` と `.aidea/backchannels/` は初回のみ `BackchannelSetup.setup()` が作成・複製する
- `.aidea/claude/companions/<0..8>/instructions.md` も `BackchannelSetup.setup()` が `Backchannels/companion-instructions.md` を 9 個に複製する (既存ファイルは上書きしない)
- `.aidea/config/concier-schedule.yaml` は `BackchannelSetup.setup()` が不在時のみ Bundle テンプレ `Backchannels/concier-schedule.yaml` からコピーする
- `.aidea/state/concier-notified.json` は `cc.schedule-voice` スキルが初回実行時に自動生成する (Aidea は管理しない)
- `.aidea/claude/aidea.md` 内のマーカー領域 (`<!-- aidea:companions:start --> ... <!-- aidea:companions:end -->`) は `CompanionRosterWriter` が `WorkspaceSnapshotManager.apply()` 末尾と `CompanionEditView` のリネーム確定時に runtime 更新する (詳細: [../backchannels/companion-roster.md](../backchannels/companion-roster.md))
- v2 以前の旧ファイル `.aidea/companions.json` / `.aidea/recommends.json` は起動時に `WorkspaceSnapshotManager` が `workspace.json` v3 に統合して自動削除する

---

## ファイル詳細

### `workspace.json` (統合スナップショット)

- **管理**: `Services/Workspace/WorkspaceSnapshotManager.swift`
- **フォーマット**: JSON (`version: 8`)
- **初期値の SSoT**: Bundle 同梱の `Aidea/Resources/default-workspace.json` (ハードコード排除)
- **読込フロー** (`WorkspaceSnapshotManager.load(projectRoot:)`):
  1. `<projectRoot>/.aidea/workspace.json` が存在 → 読込・マイグレーション適用
  2. 不在 → Bundle 同梱の `default-workspace.json` を読込・初期スナップショットとして返す
  3. Bundle 読込も失敗 → nil を返す (AideaApp 側で緊急フォールバック)
- **書出タイミング**: 初回起動時にテンプレを適用しても **即書出はしない**。アプリ終了時 / バックグラウンド化時に通常の保存フローで `<projectRoot>/.aidea/workspace.json` が初めて生成される
- **緊急フォールバック** (`AideaApp.init()`): Bundle 読込にも失敗した場合は **Filer 1 ペインの最小レイアウト** を生成して継続起動する (通常は発生しない)

#### スキーマ (v7)

トップレベルは 4 つの意味的グループに分かれる。

| グループ | 説明 |
|---|---|
| `layout` | ペイン構造 + アクティブペイン |
| `sessions` | 各 Session タブの永続化状態 + アクティブ履歴 |
| `companions` | 9 個固定のコンパニオン定義 + Claude セッション紐付け |
| `recommends` | scene → レコメンドプロンプト設定 |

```jsonc
{
  "version": 7,
  "layout": {
    "tree": { /* LayoutNodeSnapshot ツリー (split/leaf 再帰) */ },
    "activePaneID": "<UUID>" // または null
  },
  "sessions": {
    "previews": [{ "id": {...}, "url": "...", "title": "..." }],
    "webs":     [{ "id": {...}, "url": "..." }],
    "filers":   [{ "id": {...}, "expandedURLs": [...], "excludeRules": [...], "userDecorationRules": [...] }],
    "kits":     [{ "id": {...}, "expandedSections": [...], "expandedGroups": [...] }],
    "activeHistory": [/* SessionID 配列 */]
  },
  "companions": [
    {
      "index": 0,
      "name": "Companion 1",
      "icon": "Companions/companion-1",
      "sessionID": null            // null = 未起動 / SessionID = 起動中の Claude セッション
    },
    /* ... index 1〜8 まで必ず 9 要素 ... */
    // v8 で initialPrompt フィールドは削除。指示書本文は
    // .aidea/claude/companions/<index>/instructions.md に外部化 (ADR 0022)
  ],
  "recommends": {
    "git:workingChanges": { "prompts": ["..."], "defaultCompanionIndex": 0 }
  }
}
```

#### マイグレーション履歴

| 版 | 変更内容 | マイグレーション |
|---|---|---|
| v2 | レイアウトを LayoutNode ツリーで保存する形式 | (基底) |
| v3 | `companions` / `companionBindings` / `recommends` を統合 | 旧 `.aidea/companions.json` / `.aidea/recommends.json` を読み込んで統合し削除 |
| v4 | Filer Tab に `excludeRules` を追加 (issue #68) | nil 時にデフォルト除外ルールを設定 |
| v5 | `activeSessionHistory` を追加 (issue #49) | nil 時に空配列扱い |
| v6 | Filer Tab に `userDecorationRules` を追加 (issue #9) | nil 時に空配列扱い (デフォルトデコレーションは Aidea 同梱定数) |
| v7 | **構造を 4 グループ化 + コンパニオン UUID → index 化 + bindings 統合 (issue #80)** | 後述 |
| v8 | **コンパニオン `initialPrompt` フィールドを削除し、指示書を `.aidea/claude/companions/<index>/instructions.md` に外部化 (ADR 0022)** | 後述 |

#### v6 → v7 マイグレーションの詳細

1. **トップレベル平坦構造の集約**:
   - `layoutRoot` / `activePaneID` → `layout.{tree, activePaneID}`
   - `previews` / `webs` / `filers` / `kits` / `activeSessionHistory` → `sessions.{previews, webs, filers, kits, activeHistory}`
2. **コンパニオン UUID → index 化** + **bindings 統合**:
   - 旧 `companions: [{ id: UUID, name, icon, initialPrompt }]` の各要素について、`icon` 名 (`Companions/companion-N`) から `index` を逆算 (`N - 1`)
   - 推定できない companion (icon が想定外形式) は捨てる。同じ index に複数該当した場合は後勝ち
   - 旧 `companionBindings: [{ companionID, sessionID }]` を、対応する new companion の `sessionID` フィールドに移植
   - 9 個の枠に該当データが無い index は Bundle テンプレの初期値で埋める (name/icon/initialPrompt はテンプレを採用)
3. **recommends は構造変更なし** (キー名・形式そのまま)

#### v7 → v8 マイグレーションの詳細

1. **`companions[].initialPrompt` 削除**: v7 までフィールドに保持していた initialPrompt 文字列を、各 `index` について以下の処理で外部化する
   - 対象パス: `<projectRoot>/.aidea/claude/companions/<index>/instructions.md`
   - **ファイル不在時のみ書き出し**: ユーザが既に手動編集している場合の上書きを避ける
   - 親ディレクトリ (`.aidea/claude/companions/<index>/`) は自動生成
2. v8 スナップショット返却時には `initialPrompt` フィールドを含めない (Codable 側で削除済み)
3. 以降の保存からは v8 として書き出される

新規プロジェクト (workspace.json 不在) は `BackchannelSetup.setup()` が `Backchannels/companion-instructions.md` を 9 個に複製する経路で初期化される。

### `default-workspace.json` の構造ルール

- `workspace.json` のスキーマと **完全に一致** させる (フィールド省略不可)
- 値が空の場合も配列は `[]` / 辞書は `{}` を明示
- `version` は現行スキーマバージョンと一致
- `companions` には必ず 9 要素 (index 0〜8) を含め、`sessionID` は全て `null`
- レイアウト・companion 名称・recommend プロンプト等の **デフォルト値はすべてここに集約**。Swift コード側へのハードコードは禁止
- v8 以降は `companions[].initialPrompt` を含めない (ファイル化したため)。指示書テンプレ本文は `Aidea/Resources/Backchannels/companion-instructions.md` (Bundle 同梱) が SSoT

### `.aidea/ja/<path>` (翻訳キャッシュ)

- **管理**: `Services/Translation/TranslationCache.swift`
- **フォーマット**: Markdown (翻訳結果そのまま)
- **鮮度判定**: 元ファイルとの mtime 比較で再翻訳要否を決める

---

## Backchannel 通信

Claude → Aidea 方向の通信は**ファイル経由**で行う。詳細は [../backchannels/backchannel.md](../backchannels/backchannel.md) を参照。

### フロー

```
1. Claude セッション起動時
   └─ Aidea が固定パターン文字列 (.aidea/claude/companions/<index>/instructions.md
      を読んで従ってね) を PTY に送信 (ADR 0022)
   └─ Claude が instructions.md を読み、さらに参照先の .aidea/claude/aidea.md /
      speech.md / handoff.md を段階的に読み込む

2. Claude が「作業開始時」と「レスポンス末尾」の 2 回、以下を実行:
   ├─ 作業開始時: .aidea/backchannels/<companion-index>/speech-{timestamp}.txt に
   │  作業開始の ack (「了解 やっていくね」等) を書き出す (issue #113)
   └─ レスポンス末尾: 同ディレクトリに要約テキストを書き出す
      (100 文字以内の日本語、英単語はカタカナ化、記号省略)
   ※ ディレクトリがなければ Claude 側で mkdir -p 相当で作成
   ※ 1 プロンプトで複数の speech ファイルが出るため timestamp 順で再生される

3. SpeechWatcher (FSEvents) が .aidea/backchannels/ を再帰監視
   ├─ 親ディレクトリが 0..8 の整数である speech-*.txt を検知 (それ以外は警告ログのみで無視)
   ├─ コンテンツ + companionIndex をコールバックで SpeechState に渡す
   └─ ファイルは削除せず残す (ADR 0024: 作業履歴として保全)

4. SpeechQueue が VOICEVOX Service (localhost:50021) に投げて読み上げ
```

### 関連クラス

| ファイル | 役割 |
|---|---|
| `Services/Backchannel/BackchannelSetup.swift` | Bundle → `.aidea/claude/` の初期コピー (`aidea.md` / `speech.md` / `handoff.md` / `output.md` / コンパニオン指示書 9 個) |
| `Services/Backchannel/Speech/SpeechWatcher.swift` | `.aidea/backchannels/<0..8>/speech-*.txt` の FSEvents 再帰監視 |
| `Services/Backchannel/Speech/SpeechState.swift` | Speech 状態管理と SpeechQueue への投入 |
| `Services/Backchannel/Speech/SpeechQueue.swift` | VOICEVOX 合成 → AVAudioPlayer 再生キュー |
| `Services/Backchannel/Handoff/HandoffWatcher.swift` | `.aidea/backchannels/<0..8>/handoff-*.json` の FSEvents 再帰監視 |
| `Services/Backchannel/Handoff/HandoffState.swift` | Handoff 状態管理 + Dispatcher 呼び出し |
| `Services/Backchannel/Output/OutputWatcher.swift` | `.aidea/backchannels/<0..8>/output-*.txt` の FSEvents 再帰監視 |
| `Services/Backchannel/Output/OutputState.swift` | Output 履歴蓄積 (コンパニオン別インメモリ) |

詳細は [../backchannels/](../backchannels/README.md) を参照。

---

## 永続化タイミング一覧

| タイミング | 対象 | 呼び出し元 |
|---|---|---|
| 起動時 | UserDefaults → `projectRoot` 復元 | `WorkspaceState.init()` |
| 起動時 (workspace.json 既存) | `workspace.json` 読込 → 復元・マイグレーション適用 | `WorkspaceSnapshotManager.load()` |
| 起動時 (workspace.json 不在) | Bundle 同梱 `default-workspace.json` 読込 → 初期スナップショットとして適用 | `WorkspaceSnapshotManager.load()` |
| 起動時 (Bundle 読込も失敗) | Filer 1 ペインの最小レイアウトを生成して継続起動 (緊急フォールバック) | `AideaApp.init()` |
| projectRoot 変更時 | `.aidea/` 生成 + `.git/info/exclude` 追記 + Backchannel 再初期化 | `WorkspaceState.setProjectRoot()` |
| Companion / Recommend 変更時 | インメモリのみ更新 (即座保存しない) | `CompanionStore` / `RecommendStore` |
| Claude から speech 受信時 | `<n>/speech-*.txt` → 読み上げ (ファイルは残す、ADR 0024) | `SpeechWatcher` |
| Claude から handoff 受信時 | `<n>/handoff-*.json` → 宛先解決 → 送信 (ファイルは残す、ADR 0024) | `HandoffWatcher` |
| Claude から output 受信時 | `<n>/output-*.txt` → OutputState の履歴に蓄積 (ファイルは残す、ADR 0024) | `OutputWatcher` |
| Claude がコンテキスト書き出し時 | `<n>/context.txt` → 上書き更新 (セッション間記憶保持、[../backchannels/context.md](../backchannels/context.md)) | Claude 自律管理 (Aidea 側監視なし) |
| 終了時 / バックグラウンド化時 | `workspace.json` (4 グループ統合) 保存 | `AideaApp.registerTerminationObserver()` |

---

## 設計ポリシー

- **プロジェクト固有は `.aidea/`**: 複数プロジェクトをまたいだ干渉を避けるため、プロジェクト固有の状態・リソース・通信データはすべて `<projectRoot>/.aidea/` に集約する
- **グローバル設定は UserDefaults**: プロジェクトに依存しないユーザ設定のみ
- **機密情報は Keychain**: API キー等は macOS 標準の Keychain に委譲
- **デフォルト値は Bundle Resources**: ハードコードを避け、Swift と JSON の二重管理を排する
- **`.aidea/` のローカル ignore**: Aidea が `.git/info/exclude` に自動追記する。共有 `.gitignore` は触らないため、チームメンバーへの影響ゼロ。`.aidea/` をコミット対象にしたい運用にも対応できる (ADR 0026)
- **ファイルフォーマットは JSON / Markdown / Plain Text**: バイナリは使わず、直接編集・diff 可能にする

---

## 関連ドキュメント

- [../architecture.md](../architecture.md) — 全体のアーキテクチャ
- [../backchannels/](../backchannels/README.md) — 通信チャネル (Claude → Aidea) の詳細
- [../frontchannels/](../frontchannels/README.md) — 通信チャネル (Aidea → Claude) の詳細
- [../sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) — Session 概念
- [../companions/companion.md](../companions/companion.md) — コンパニオン仕様 (9 個固定 + index 識別)
