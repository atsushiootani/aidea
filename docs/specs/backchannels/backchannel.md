---
title: Backchannel 仕様
description: Aidea と Claude のファイルベース IPC 機構。設計原則・.aidea/ ディレクトリ構造・機能宣言チェーン・ファイル監視 (FSEvents)・コンパニオン instructions.md
derived_from:
  - docs/decisions/0022-companion-instructions-as-files.md
syncs_with:
  - docs/specs/backchannels/voicevox.md
  - docs/specs/aspects/persistence.md
  - docs/specs/companions/companion.md
impacts:
  - docs/specs/tools/claude.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-23
---

# Backchannel 仕様

> Aidea と Claude のファイルベース IPC 機構

## 概要

**Backchannel** は、Aidea アプリとターミナル上で動作する Claude インスタンス間の
ファイルベース通信プロトコル。Aidea は Claude の振る舞いを設定ファイルで制御し、
Claude はファイル書き出しで Aidea にフィードバックを返す。

Aidea は `.aidea/` ディレクトリを共有バスとして使用し、FSEvents でファイル変更を
検知して UI に反映する。

---

## 設計原則

1. **ファイルが API** — プロセス間通信はすべてファイル読み書きで行う
2. **機能宣言方式** — コンパニオンの `initialPrompt` で `.aidea/claude/{feature}.md` を参照することで、Claude 側の Backchannel 機能を有効化する
3. **ターミナル非依存** — ターミナル出力のパースに依存せず、Claude が明示的にファイルを書く
4. **複数ターミナル対応** — 各ターミナルセッションが固有の ID で隔離されたディレクトリを持つ

---

## ディレクトリ構造

```
.aidea/
├── claude/
│   ├── aidea.md              # Aidea 環境の共通指示 (instructions.md から参照される土台)
│   ├── speech.md             # 読み上げ機能の定義 (同上)
│   ├── {feature}.md          # 将来の共有機能ごとに 1 ファイル
│   └── companions/
│       ├── 0/
│       │   ├── instructions.md  # ← Aidea が起動時に "読んで" と指示するエントリーポイント
│       │   └── *.md             # (任意) 段階的開示の参照先 (persona.md など)
│       ├── 1/instructions.md
│       └── ...                  # 0…8 の 9 ディレクトリ固定 (ADR 0022)
├── backchannels/
│   ├── speech-{timestamp}.txt  # VOICEVOX 読み上げ用テキスト
│   ├── notify-{timestamp}.txt  # 通知バナー用テキスト (将来)
│   └── ...                     # 将来の Backchannel メッセージ
└── workspace.json              # 既存: レイアウト永続化
```

### パス規約

- `{id}`: ターミナルセッションの一意識別子（UUID またはインスタンス番号）
- `{timestamp}`: ISO 8601 コンパクト形式 (`20260413T153000`)
- `{feature}`: Backchannel 機能名 (例: `speech`)

---

## 機能宣言チェーン

Aidea は Claude セッション起動時に、`companionIndex` から派生した固定パターン文字列 **のみ** を Claude に送信する (v8 以降)。
共通プロンプトのハードコードや `CLAUDE.md` への自動追記は行わない。

```
.aidea/claude/companions/<index>/instructions.md を読んで従ってね
```

文字列の生成は `Services/Companion/CompanionInstructions.swift` (`loadCommand(for:)`) に集約される。

### コンパニオン側の指示書

`.aidea/claude/companions/<index>/instructions.md` 本文は **ユーザが自由に編集できる Markdown**。共通の Backchannel 機能は本文冒頭で `.aidea/claude/aidea.md` / `speech.md` を参照することで有効化する。デフォルトテンプレ (Bundle 同梱 `Backchannels/companion-instructions.md`) はこの参照行 + 役割記入欄の 2 つを持つ。

例 (デフォルト):

```markdown
# Companion 指示書

.aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね。

## このコンパニオンの役割

(ここに固有の役割を書いてね。例: テスト担当 / レビュー担当 / etc)
```

例 (テスト担当 Companion にカスタマイズ):

```markdown
# Companion 2: テスト担当

.aidea/claude/aidea.md を読んで従ってね。

あなたはテスト担当です。コードを変更したら必ず関連テストを走らせ、結果を要約してください。
```

instructions.md 内から相対参照 (`./persona.md` など) で他ファイルを段階的に読ませることもできる (詳細は ADR 0022)。

### 機能ファイルの構成

| ファイル | 役割 | 配置 |
|---|---|---|
| `aidea.md` | Aidea 環境の共通指示 (Backchannel 機能の土台) | `.aidea/claude/` 直下 (全 Companion 共有) |
| `speech.md` | 読み上げ機能の定義 | 同上 |
| `{feature}.md` | 将来の共有機能 | 同上 |
| `companions/<index>/instructions.md` | コンパニオンごとの起動指示 (エントリーポイント) | `.aidea/claude/companions/<0..8>/` |
| `companions/<index>/*.md` | 段階的開示用の補助ファイル (persona / workflow など) | 同上 |

`BackchannelSetup.setup()` が初回セットアップ時に Bundle 内の既知ファイルを `.aidea/claude/` にコピーする (`aidea.md` / `speech.md` / `companions/<0..8>/instructions.md` を `Backchannels/companion-instructions.md` から複製)。**既存ファイルは上書きしない** (ユーザ編集の保護)。

---

## ファイル監視

Aidea は `.aidea/backchannels/` ディレクトリを FSEvents で監視する。
ファイルパターンに応じて対応するハンドラにディスパッチする。

| ファイルパターン | ハンドラ | 参照仕様 |
|-----------------|---------|---------|
| `speech-*.txt` | SpeechWatcher → VoicevoxService | [voicevox.md](./voicevox.md) |

---

## メッセージ種別（現在 + 将来）

| 種別 | ファイルパターン | 形式 | 用途 |
|------|-----------------|------|------|
| **Speech** | `speech-{timestamp}.txt` | プレーンテキスト | VOICEVOX 読み上げ |
| Notification | `notify-{timestamp}.txt` | プレーンテキスト | 通知バナー表示 |
| Action | `action-{timestamp}.json` | JSON | UI 操作の指示 |
| Status | `status.json` | JSON | Claude の作業状態表示 |

**太字**は実装済み / 実装予定。それ以外は将来の拡張ポイント。

---

## 境界

### Always
- `.aidea/` 配下のファイル監視は FSEvents を使う
- 処理済みファイルは削除してクリーンアップする
- 全ターミナルから `.aidea/backchannels/` に書き出す
- `.aidea/claude/{feature}.md` と `.aidea/claude/companions/<0..8>/instructions.md` は初回セットアップ時に Bundle からコピーする
- Claude セッション起動時に送信するのは `CompanionInstructions.loadCommand(for:)` で生成した固定パターン文字列のみ

### Never
- ターミナル出力の直接パースに依存しない
- Claude のプロンプトパターンマッチに依存しない
- `.aidea/claude/{feature}.md` および `.aidea/claude/companions/<index>/instructions.md` の既存ファイルを上書きしない (ユーザ編集を保護)
- Aidea 側から共通プロンプトをハードコードで送信しない
- `CompanionConfig` に `initialPrompt` 文字列を再追加しない (v8 で外部化済み、ADR 0022)
- `CLAUDE.md` を Aidea が自動改変しない
