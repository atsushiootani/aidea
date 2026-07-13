---
title: Persistence (データ永続化)
description: UserDefaults / Keychain / Bundle Resources / .aidea/ のデータ永続化と初期値テンプレ仕様を機能群横断で集約 (.aidea/widgets/ 含む)
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
  - docs/specs/backchannels/remind.md
  - docs/specs/backchannels/inbox.md
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
  - docs/specs/widgets/quick-memo.md
impacts: []
conventions:
  - docs/LAYOUT.md
  - docs/specs/aspects/README.md
last_updated: 2026-07-13
---

# Persistence (データ永続化)

Aidea が **どのデータをどこに、どのタイミングで保存するか** の仕様。

保存先は大きく 4 種類:

1. **UserDefaults** — アプリ全体のユーザ設定 (最小限)
2. **Keychain** — 機密情報 (API キー)
3. **Bundle Resources** — アプリ同梱の初期値テンプレ・指示書 (読み取り専用)
4. **`<projectRoot>/.aidea/`** — プロジェクト固有の状態・リソース・通信データ・Widget 永続テキスト (メイン)

`~/Library/Application Support/Aidea/` は **現時点では使用していない**。プロジェクト固有の情報は `.aidea/` 配下に集約することで、プロジェクトをまたいだ干渉を防いでいる。

---

## 保存先ごとのデータ

### UserDefaults (アプリ全体設定)

| キー | 型 | 用途 |
|---|---|---|
| `aidea.projectRoot` | String | 最後に開いていたプロジェクトのパス。起動時復元用 |

起動時に読込、プロジェクトディレクトリ変更時に書込する。

### Keychain (機密情報)

| サービス | 用途 |
|---|---|
| `com.aidea.anthropic-api-key` | Anthropic API キー (翻訳・ディレクトリ概要生成機能で使用) |

保存・読込・削除は Keychain アクセスを担うヘルパに集約する。
利用: 翻訳機能 / ディレクトリ概要生成機能

### Bundle Resources (`Aidea/Resources/`)

アプリバンドルに同梱する **初期値テンプレ・指示書**。`Aidea/Resources/` 配下はファイル追加だけで自動的にビルドへ含まれる (プロジェクトファイルの編集不要)。

| パス | 用途 |
|---|---|
| `default-workspace.json` | `<projectRoot>/.aidea/workspace.json` の初期テンプレ (ハードコード排除の SSoT) |
| `Backchannels/aidea.md` | Backchannel 機能の指示書。初回セットアップ処理が `.aidea/claude/` にコピー |
| `Backchannels/speech.md` | speech 機能の指示書 (同上) |
| `Backchannels/handoff.md` | Companion 間ハンドオフ機能の指示書 (同上)。詳細は [../backchannels/handoff.md](../backchannels/handoff.md) |
| `Backchannels/output.md` | output 記録機能の指示書 (同上)。詳細は [../backchannels/output.md](../backchannels/output.md) |
| `Backchannels/companion-instructions.md` | コンパニオン指示書 (`instructions.md`) のデフォルトテンプレ。初回セットアップ処理が 9 個に複製して `.aidea/claude/companions/<0..8>/instructions.md` に配置 (既存ファイルは上書きしない) |
| `Backchannels/remind.md` | リマインド機能の指示書。初回セットアップ処理が `.aidea/claude/` にコピー |

**設計ポリシー**: ハードコードしがちなデフォルト値 (初期レイアウト・コンパニオン定義・レコメンドプロンプト等) はコード側に二重管理せず、Bundle 同梱の JSON / Markdown を **唯一のソース** とする。

### `<projectRoot>/.aidea/` (プロジェクト固有)

```
<projectRoot>/.aidea/
├── workspace.json            # レイアウト・Session 状態・コンパニオン・レコメンド・履歴の統合スナップショット (v8)
├── backchannels/             # Claude からのメッセージ受信ディレクトリ (ADR 0024: Companion 別に分離し履歴保全)
│   ├── 0/                    # Companion 0 のメッセージ置き場
│   │   ├── speech-*.txt      # 読み上げ対象テキスト (処理後も残す / 履歴)
│   │   ├── handoff-*.json    # Companion 0 が送信したハンドオフ (処理後も残す、[../backchannels/handoff.md](../backchannels/handoff.md))
│   │   ├── output-*.txt      # レスポンス全文の出力記録 (処理後も残す / 履歴、[../backchannels/output.md](../backchannels/output.md))
│   │   └── remind-*.txt      # 遅延発火型リマインド (発火後 `.fired.txt` にリネーム、[../backchannels/remind.md](../backchannels/remind.md))
│   ├── 1/                    # Companion 1
│   │   └── ...
│   ├── ...                   # 0..8 (必要に応じて Claude が mkdir で作成)
│   └── inbox/                # 外部プロセスからの受信箱 (Companion 別ではない、[../backchannels/inbox.md](../backchannels/inbox.md))
│       └── *.json            # {"to": <index|name>, "message": "..."} (処理後も残す、ADR 0037)
├── claude/                   # Claude 起動時に読ませるリソース
│   ├── aidea.md              # Backchannel 機能の指示書 (共有)
│   ├── speech.md             # speech 機能の指示書 (共有)
│   ├── handoff.md            # Companion 間ハンドオフの指示書 (共有)
│   ├── output.md             # output 記録機能の指示書 (共有)
│   ├── remind.md             # リマインド機能の指示書 (共有)
│   └── companions/           # コンパニオン別の指示書 (v8 新設)
│       ├── 0/
│       │   ├── instructions.md  # ← Aidea が起動時に "読んで" と指示するエントリーポイント
│       │   └── *.md             # (任意) 段階的開示の参照先
│       ├── 1/instructions.md
│       └── ...                  # 0…8 の 9 ディレクトリ固定
├── config/                   # ユーザが宣言的に編集する機能設定 (JSON)
│   └── scheduler.json        # 定時スケジューラのジョブ定義 (jobs[]、[../widgets/scheduler.md](../widgets/scheduler.md))
├── state/                    # 機能の自動管理ランタイム状態 (JSON、ユーザは通常編集しない)
│   ├── scheduler.json        # 定時スケジューラの lastRun マップ (jobId→YYYY-MM-DD、[../widgets/scheduler.md](../widgets/scheduler.md))
│   └── dir-summaries.json    # ディレクトリ AI 要約のキャッシュ (相対パス→1行要約、[../tools/filer.md](../tools/filer.md)#showdirectorysummary)
├── widgets/                  # Widget が永続化するユーザ編集可能テキスト
│   └── quickmemo/
│       └── memo.md           # クイックメモ (固定 1 ファイル、上書き運用 / widgets/quick-memo.md)
└── ja/                       # 英語ドキュメントの日本語翻訳キャッシュ
    └── <相対パス>/<filename>
```

- `projectRoot` が変わるたびに `.aidea/` と `.aidea/ja/` を生成し、**`.git/info/exclude` (ローカル専用 ignore) に `.aidea/` を追記** する。`.git/info/` が存在しない非 git プロジェクトでは追記をスキップする
- `.aidea/claude/*.md` と `.aidea/backchannels/` は初回のみ初回セットアップ処理が作成・複製する
- `.aidea/claude/companions/<0..8>/instructions.md` も初回セットアップ処理が `Backchannels/companion-instructions.md` を 9 個に複製する (既存ファイルは上書きしない)
- `.aidea/claude/aidea.md` 内のマーカー領域 (`<!-- aidea:companions:start --> ... <!-- aidea:companions:end -->`) は、スナップショット適用の末尾とコンパニオン編集でのリネーム確定時に runtime 更新される (詳細: [../backchannels/companion-roster.md](../backchannels/companion-roster.md))
- v2 以前の旧ファイル `.aidea/companions.json` / `.aidea/recommends.json` は起動時に `workspace.json` v3 に統合して自動削除する
- `.aidea/widgets/` 配下は **Widget が初回保存時に自動生成** する (Aidea 起動時の一括初期化は行わない)。Widget が永続化するユーザ編集可能テキストを置くカテゴリで、現状は `quickmemo/memo.md` のみ。今後 Widget が増えたら `.aidea/widgets/<widget-name>/` に並べる
- `.aidea/config/scheduler.json` は**ユーザが宣言的に編集**する定時スケジューラの設定 (ジョブ配列)。不在時はジョブ無し扱い。起動時に読込のみ行い (ランタイム再読込なし)、popover からの ON/OFF トグルだけ read-modify-write する ([../widgets/scheduler.md](../widgets/scheduler.md))
- `.aidea/state/scheduler.json` は**自動管理**の `lastRun` マップ (jobId→`YYYY-MM-DD`)。定刻発火・手動「今すぐ実行」時に、整形・キーソート済み JSON としてアトミック書き込みされる。ディレクトリは書込時に自動生成

---

## ファイル詳細

### `workspace.json` (統合スナップショット)

- **管理**: スナップショット管理を担うコンポーネントが読み書きを一元化する
- **フォーマット**: JSON (`version: 8`)
- **初期値の SSoT**: Bundle 同梱の `default-workspace.json` (ハードコード排除)
- **読込フロー** (起動時):
  1. `<projectRoot>/.aidea/workspace.json` が存在 → 読込・マイグレーション適用
  2. 不在 → Bundle 同梱の `default-workspace.json` を読込・初期スナップショットとして返す
  3. Bundle 読込も失敗 → 緊急フォールバックへ
- **書出タイミング**: 初回起動時にテンプレを適用しても **即書出はしない**。アプリ終了時 / バックグラウンド化時に通常の保存フローで `<projectRoot>/.aidea/workspace.json` が初めて生成される
- **緊急フォールバック**: Bundle 読込にも失敗した場合は **Filer 1 ペインの最小レイアウト** を生成して継続起動する (通常は発生しない)

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
    "tree": { /* レイアウトツリー (split/leaf 再帰) */ },
    "activePaneID": "<UUID>" // または null
  },
  "sessions": {
    "previews": [{ "id": {...}, "url": "...", "title": "..." }],
    "webs":     [{ "id": {...}, "url": "..." }],
    "filers":   [{ "id": {...}, "expandedURLs": [...], "excludeRules": [...], "userDecorationRules": [...] }],
    "kits":     [{ "id": {...}, "expandedSections": [...], "expandedGroups": [...] }],
    "activeHistory": [/* セッション ID の配列 */],
    "customTitles": [{ "id": {...}, "title": "..." }] // タブのカスタム名 (optional、nil 時は空扱い。バージョン bump 不要)
  },
  "companions": [
    {
      "index": 0,
      "name": "Companion 1",
      "icon": "Companions/companion-1",
      "sessionID": null            // null = 未起動 / セッション ID = 起動中の Claude セッション
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
| v2 | レイアウトをツリー構造で保存する形式 | (基底) |
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
2. v8 スナップショット返却時には `initialPrompt` フィールドを含めない (スキーマから削除済み)
3. 以降の保存からは v8 として書き出される

新規プロジェクト (workspace.json 不在) は初回セットアップ処理が `Backchannels/companion-instructions.md` を 9 個に複製する経路で初期化される。

### `default-workspace.json` の構造ルール

- `workspace.json` のスキーマと **完全に一致** させる (フィールド省略不可)
- 値が空の場合も配列は `[]` / 辞書は `{}` を明示
- `version` は現行スキーマバージョンと一致
- `companions` には必ず 9 要素 (index 0〜8) を含め、`sessionID` は全て `null`
- レイアウト・companion 名称・recommend プロンプト等の **デフォルト値はすべてここに集約**。コード側へのハードコードは禁止
- v8 以降は `companions[].initialPrompt` を含めない (ファイル化したため)。指示書テンプレ本文は Bundle 同梱のテンプレが SSoT

### `.aidea/ja/<path>` (翻訳キャッシュ)

- **管理**: 翻訳キャッシュを担うコンポーネント
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

3. speech 監視処理 (FSEvents) が .aidea/backchannels/ を再帰監視
   ├─ 親ディレクトリが 0..8 の整数である speech-*.txt を検知 (それ以外は警告ログのみで無視)
   ├─ コンテンツ + companionIndex を音声キューに渡す
   └─ ファイルは削除せず残す (ADR 0024: 作業履歴として保全)

4. 音声キューが VOICEVOX (localhost:50021) に投げて読み上げ
```

### 関連する処理 (役割別)

| 役割 | 内容 |
|---|---|
| 初回セットアップ処理 | Bundle → `.aidea/claude/` の初期コピー (`aidea.md` / `speech.md` / `handoff.md` / `output.md` / `remind.md` / コンパニオン指示書 9 個) |
| speech 監視処理 | `.aidea/backchannels/<0..8>/speech-*.txt` の FSEvents 再帰監視。検知内容を音声キューに投入 |
| 音声キュー | VOICEVOX 合成 → 音声再生キュー |
| handoff 監視処理 | `.aidea/backchannels/<0..8>/handoff-*.json` の FSEvents 再帰監視。宛先解決と配送を呼び出す |
| output 監視処理 | `.aidea/backchannels/<0..8>/output-*.txt` の FSEvents 再帰監視。履歴をコンパニオン別にインメモリ蓄積 |
| remind 監視処理 | `.aidea/backchannels/<0..8>/remind-{YYYYMMDDTHHmmss}.txt` の FSEvents 再帰監視 + 起動時スキャン |
| リマインドスケジューラ | トリガ時刻まで待機して音声キューに投入、発火後にファイルを `.fired.txt` リネーム |

詳細は [../backchannels/](../backchannels/README.md) を参照。

---

## 永続化タイミング一覧

| タイミング | 対象 | 担当 (役割) |
|---|---|---|
| 起動時 | UserDefaults → `projectRoot` 復元 | ワークスペース状態の初期化 |
| 起動時 (workspace.json 既存) | `workspace.json` 読込 → 復元・マイグレーション適用 | スナップショット管理 |
| 起動時 (workspace.json 不在) | Bundle 同梱 `default-workspace.json` 読込 → 初期スナップショットとして適用 | スナップショット管理 |
| 起動時 (Bundle 読込も失敗) | Filer 1 ペインの最小レイアウトを生成して継続起動 (緊急フォールバック) | アプリ起動処理 |
| projectRoot 変更時 | `.aidea/` 生成 + `.git/info/exclude` 追記 + Backchannel 再初期化 | ワークスペース状態の切替処理 |
| Companion / Recommend 変更時 | インメモリのみ更新 (即座保存しない) | コンパニオン / レコメンドの管理 |
| Claude から speech 受信時 | `<n>/speech-*.txt` → 読み上げ (ファイルは残す、ADR 0024) | speech 監視処理 |
| Claude から handoff 受信時 | `<n>/handoff-*.json` → 宛先解決 → 送信 (ファイルは残す、ADR 0024) | handoff 監視処理 |
| Claude から output 受信時 | `<n>/output-*.txt` → 履歴に蓄積 (ファイルは残す、ADR 0024) | output 監視処理 |
| Claude から remind 受信時 | `<n>/remind-{ts}.txt` → トリガ時刻まで待機し音声キュー投入 → ファイルを `.fired.txt` リネーム ([../backchannels/remind.md](../backchannels/remind.md)) | remind 監視処理 + リマインドスケジューラ |
| 外部から inbox 受信時 | `inbox/*.json` → 宛先 Companion を解決して `message` を送信 (ファイルは残す、[../backchannels/inbox.md](../backchannels/inbox.md)) | inbox 監視処理 + 配送処理 |
| クイックメモ保存時 | `.aidea/widgets/quickmemo/memo.md` を上書き (親ディレクトリ自動生成、[../widgets/quick-memo.md](../widgets/quick-memo.md)) | クイックメモ保存処理 |
| 起動時 (scheduler) | `.aidea/config/scheduler.json` 読込 → 有効ジョブ登録 + 取りこぼし判定。`state/scheduler.json` で当日実行済みを照合 ([../widgets/scheduler.md](../widgets/scheduler.md)) | スケジューラの設定読込・判定処理 |
| スケジューラ発火 / 今すぐ実行時 | 指定 Companion へ command 送信 → `state/scheduler.json` の `lastRun[id]` を当日日付で更新 (アトミック書き込み) | スケジューラ実行処理 |
| ディレクトリ要約 生成時 | `state/dir-summaries.json` を上書き保存 (アトミック書き込み。保存済みは再生成しない、[../tools/filer.md](../tools/filer.md)#showdirectorysummary) | ディレクトリ要約キャッシュ管理 |
| スケジューラ ON/OFF トグル時 | `config/scheduler.json` の該当ジョブ `enabled` を read-modify-write | スケジューラ設定の更新処理 |
| 終了時 / バックグラウンド化時 | `workspace.json` (4 グループ統合) 保存 | アプリ終了・バックグラウンド化の監視処理 |

---

## 設計ポリシー

- **プロジェクト固有は `.aidea/`**: 複数プロジェクトをまたいだ干渉を避けるため、プロジェクト固有の状態・リソース・通信データはすべて `<projectRoot>/.aidea/` に集約する
- **グローバル設定は UserDefaults**: プロジェクトに依存しないユーザ設定のみ
- **機密情報は Keychain**: API キー等は macOS 標準の Keychain に委譲
- **デフォルト値は Bundle Resources**: ハードコードを避け、コードと JSON の二重管理を排する
- **`.aidea/` はローカル専用 ignore**: Aidea が自動で `.git/info/exclude` に追記する。共有 `.gitignore` は一切変更しないため、チームメンバーの環境や `.aidea/` をコミット対象にしたい運用に影響しない (ADR 0026)
- **ファイルフォーマットは JSON / Markdown / Plain Text**: バイナリは使わず、直接編集・diff 可能にする

---

## 関連ドキュメント

- [../architecture.md](../architecture.md) — 全体のアーキテクチャ
- [../backchannels/](../backchannels/README.md) — 通信チャネル (Claude → Aidea) の詳細
- [../frontchannels/](../frontchannels/README.md) — 通信チャネル (Aidea → Claude) の詳細
- [../sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) — Session 概念
- [../companions/companion.md](../companions/companion.md) — コンパニオン仕様 (9 個固定 + index 識別)
