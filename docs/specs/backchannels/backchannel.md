---
title: Backchannel 仕様
description: Aidea と Claude のファイルベース IPC 機構。設計原則・.aidea/ ディレクトリ構造・機能宣言チェーン・ファイル監視 (FSEvents)・コンパニオン instructions.md
derived_from:
  - docs/decisions/0022-companion-instructions-as-files.md
  - docs/decisions/0023-companion-handoff.md
  - docs/decisions/0024-backchannel-per-companion-archive.md
syncs_with:
  - docs/specs/backchannels/voicevox.md
  - docs/specs/backchannels/handoff.md
  - docs/specs/backchannels/output.md
  - docs/specs/backchannels/remind.md
  - docs/specs/backchannels/inbox.md
  - docs/specs/backchannels/rpc.md
  - docs/specs/backchannels/companion-roster.md
  - docs/specs/backchannels/status.md
  - docs/specs/aspects/persistence.md
  - docs/specs/companions/companion.md
impacts:
  - docs/specs/tools/claude.md
conventions:
  - docs/LAYOUT.md
last_updated: 2026-08-10
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
2. **機能宣言方式** — コンパニオンの `instructions.md` で `.aidea/claude/{feature}.md` を参照することで、Claude 側の Backchannel 機能を有効化する (v8 以降、ADR 0022)
3. **ターミナル非依存** — ターミナル出力のパースに依存せず、Claude が明示的にファイルを書く
4. **Companion 別保管 + 履歴保全** — すべてのメッセージは `.aidea/backchannels/<companion-index>/` に書き出し、処理後も削除せず履歴として残す ([ADR 0024](../../decisions/0024-backchannel-per-companion-archive.md))

---

## ディレクトリ構造

```
.aidea/
├── claude/
│   ├── aidea.md              # Aidea 環境の共通指示 (instructions.md から参照される土台)
│   ├── speech.md             # 読み上げ機能の定義 (同上)
│   ├── remind.md             # リマインド機能の定義 (同上)
│   ├── inbox.md              # 外部 → Companion の inbox 書き込み作法 (外部エージェント向け参照、instructions.md からは参照しない)
│   ├── {feature}.md          # 将来の共有機能ごとに 1 ファイル
│   └── companions/
│       ├── 0/
│       │   ├── instructions.md  # ← Aidea が起動時に "読んで" と指示するエントリーポイント
│       │   └── *.md             # (任意) 段階的開示の参照先 (persona.md など)
│       ├── 1/instructions.md
│       └── ...                  # 0…8 の 9 ディレクトリ固定 (ADR 0022)
├── backchannels/                 # Companion 別サブディレクトリ配下に書き出す (ADR 0024)
│   ├── 0/
│   │   ├── speech-{timestamp}.txt     # Companion 0 の VOICEVOX 読み上げ用テキスト
│   │   ├── handoff-{timestamp}.json   # Companion 0 が送信したハンドオフ
│   │   ├── output-{timestamp}.txt     # レスポンス全文の出力記録
│   │   ├── remind-{timestamp}.txt     # 遅延発火型リマインド ({timestamp} = トリガ時刻)
│   │   ├── status.json                # フキダシに出す文字列 (上書き型。Claude が書く、status.md)
│   │   └── notify-{timestamp}.txt     # 通知バナー用テキスト (将来)
│   ├── 1/
│   │   └── ...
│   ├── ...                            # 0…8 の 9 ディレクトリ (必要時に Claude が mkdir で作成)
│   ├── inbox/                         # 外部プロセスからの受信箱 (Companion 別ではない、ADR 0037)
│   │   └── *.json                     # {"to": <index|name>, "message": "..."} ([inbox.md](./inbox.md))
│   └── rpc/                           # 外部プロセスとの往復チャネル (Companion 別ではない、ADR 0040)
│       ├── req-<id>.json              # 外部が書くリクエスト ([rpc.md](./rpc.md))
│       └── res-<id>.txt               # 宛先 Companion が書く返信 (Aidea は監視しない)
└── workspace.json                # 既存: レイアウト永続化
```

### パス規約

- `<companion-index>`: Companion の index (`0..8`、Companion 9 枠固定 / ADR 0022)
- `{timestamp}`: ISO 8601 コンパクト形式 (`20260413T153000`)
- `{feature}`: Backchannel 機能名 (例: `speech`)

### ディレクトリ作成責務

- **親 `.aidea/backchannels/`**: Aidea 側の初回セットアップ処理が作成する。FSEvents ストリームを確立するため親ディレクトリの事前存在が必要 (不在時でも監視開始は失敗しないが、stream 再確立のコストを避けるために予め作る)
- **Companion 別サブディレクトリ `<companion-index>/`**: Aidea 側では **事前作成しない**。送信元の Claude が書き出す直前に `mkdir -p` 相当で作成する (ADR 0024)。使わない Companion のディレクトリが空作成されるのを避けるため

---

## 機能宣言チェーン

Aidea は Claude セッション起動時に、`companionIndex` から派生した固定パターン文字列 **のみ** を Claude に送信する (v8 以降)。
共通プロンプトのハードコードや `CLAUDE.md` への自動追記は行わない。

```
.aidea/claude/companions/<index>/instructions.md を読んで従ってね
```

この文字列の生成は、コンパニオン指示書の起動コマンド生成ヘルパに集約される。

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
| `handoff.md` | コンパニオン間ハンドオフ機能の定義 ([handoff.md](./handoff.md)) | 同上 |
| `output.md` | output 記録機能の定義 ([output.md](./output.md)) | 同上 |
| `remind.md` | リマインド機能の定義 ([remind.md](./remind.md)) | 同上 |
| `status.md` | 作業状態フキダシ表示 (status.json への自己申告) の定義 ([status.md](./status.md)) | 同上 |
| `inbox.md` | 外部 → Companion の inbox 書き込み作法 ([inbox.md](./inbox.md))。**外部エージェント向けの参照**で、companion の instructions.md からは参照しない | `.aidea/claude/` 直下 |
| `{feature}.md` | 将来の共有機能 | 同上 |
| `companions/<index>/instructions.md` | コンパニオンごとの起動指示 (エントリーポイント) | `.aidea/claude/companions/<0..8>/` |
| `companions/<index>/*.md` | 段階的開示用の補助ファイル (persona / workflow など) | 同上 |

初回セットアップ処理が Bundle 内の既知ファイルを `.aidea/claude/` にコピーする (`aidea.md` / `speech.md` / `handoff.md` / `output.md` / `remind.md` / `inbox.md` / `status.md` / `companions/<0..8>/instructions.md` を Bundle 同梱テンプレ `Backchannels/companion-instructions.md` から複製)。**既存ファイルは上書きしない** (ユーザ編集の保護)。

`aidea.md` 内には Aidea が自動管理するコンパニオン名簿セクション (`<!-- aidea:companions:start -->` / `<!-- aidea:companions:end -->` で囲まれた領域) が含まれる。初回セットアップで aidea.md をコピーした後、スナップショット復元の末尾とコンパニオン編集 UI でのリネーム確定時に名簿書き込み処理が呼ばれ、最新の Companion 名 (`companions[].name`) でこの領域が書き換えられる。詳細は [companion-roster.md](./companion-roster.md) を参照。

---

## ファイル監視

Aidea は `.aidea/backchannels/` ディレクトリを FSEvents で **再帰監視** する (FSEvents のデフォルト挙動)。
配下のファイルをパターンで検知し、対応するハンドラにディスパッチする。

| ファイルパターン | 処理経路 | 参照仕様 |
|-----------------|---------|---------|
| `backchannels/<0..8>/speech-*.txt` | speech 監視 → VOICEVOX 読み上げ | [voicevox.md](./voicevox.md) |
| `backchannels/<0..8>/handoff-*.json` | handoff 監視 → 配送 → (宛先の) Claude セッション | [handoff.md](./handoff.md) |
| `backchannels/<0..8>/output-*.txt` | output 監視 → 出力履歴に蓄積 | [output.md](./output.md) |
| `backchannels/<0..8>/remind-{YYYYMMDDTHHmmss}.txt` | remind 監視 → 発火スケジューラ → 音声キュー (時刻到達時) | [remind.md](./remind.md) |
| `backchannels/<0..8>/status.json` | status 監視 → フキダシ文字列として保持 (上書き検知) | [status.md](./status.md) |
| `backchannels/inbox/*.json` | inbox 監視 → 配送 → (宛先の) Claude セッション | [inbox.md](./inbox.md) |
| `backchannels/rpc/req-*.json` | rpc 監視 → 配送 → (宛先の) Claude セッション (`res-*.txt` は Aidea では処理しない) | [rpc.md](./rpc.md) |

### ハンドラ通過条件

- 親ディレクトリ名が `0..8` の整数であること (範囲外・文字列ディレクトリ・`backchannels/` 直下のファイルは警告ログのみで無視)
- handoff の場合は JSON `from` フィールドとパスの `<companion-index>` が一致すること ([handoff.md](./handoff.md) 参照)
- **例外**: inbox / rpc は Companion 別ではなく `backchannels/inbox/` 直下の `*.json` / `backchannels/rpc/` 直下の `req-*.json` を対象とする (親ディレクトリ名が `inbox` / `rpc`、[inbox.md](./inbox.md) / [rpc.md](./rpc.md) 参照)

---

## メッセージ種別（現在 + 将来）

Speech / Handoff / Output / Remind は `.aidea/backchannels/<companion-index>/` 配下に書き出す (ADR 0024)。Inbox / Rpc は Companion 別ではなく `.aidea/backchannels/inbox/` / `.aidea/backchannels/rpc/` 直下に置く (ADR 0037 / 0040)。

| 種別 | ファイルパターン | 形式 | 用途 |
|------|-----------------|------|------|
| **Speech** | `<n>/speech-{timestamp}.txt` | プレーンテキスト | VOICEVOX 読み上げ |
| **Handoff** | `<n>/handoff-{timestamp}.json` | JSON | Companion 間タスク受け渡し ([handoff.md](./handoff.md)) |
| **Output** | `<n>/output-{timestamp}.txt` | プレーンテキスト | レスポンス全文の出力記録 ([output.md](./output.md)) |
| **Remind** | `<n>/remind-{timestamp}.txt` | プレーンテキスト | 遅延発火型音声リマインド ({timestamp} = トリガ時刻、発火後 `.fired.txt` にリネーム、[remind.md](./remind.md)) |
| **Inbox** | `inbox/*.json` | JSON | 外部プロセス → Companion の一方向メッセージ (Companion 別ではない、[inbox.md](./inbox.md)) |
| **Rpc** | `rpc/req-<id>.json` / `rpc/res-<id>.txt` | JSON / プレーンテキスト | 外部プロセス ⇄ Companion の往復メッセージ (Companion 別ではない、[rpc.md](./rpc.md)) |
| **Status (signal)** | `<n>/status-signal.json` | JSON | hooks が書く実行中/要返答/アイドル信号 (上書き型、[status.md](./status.md)) |
| **Status (label)** | `<n>/status-{timestamp}.json` | JSON | Claude 自身が書く自由文字列ラベル ([status.md](./status.md)) |
| Notification | `<n>/notify-{timestamp}.txt` | プレーンテキスト | 通知バナー表示 |
| Action | `<n>/action-{timestamp}.json` | JSON | UI 操作の指示 |

**太字**は実装済み / 実装予定。それ以外は将来の拡張ポイント。

---

## 境界

### Always
- `.aidea/` 配下のファイル監視は FSEvents で再帰的に行う
- 全 Backchannel メッセージは Aidea 側で **削除せず残す** (作業履歴・コンテキスト記録として保全、ADR 0024)
- Backchannel メッセージの書き出し先は `.aidea/backchannels/<companion-index>/{type}-{timestamp}.{ext}` 形式
- `<companion-index>` は `0..8` の整数のみ有効。それ以外のパスに置かれたファイルはハンドラに通さない
- `.aidea/claude/{feature}.md` と `.aidea/claude/companions/<0..8>/instructions.md` は初回セットアップ時に Bundle からコピーする
- Claude セッション起動時に送信するのは `companionIndex` から生成した指示書読み込みの固定パターン文字列のみ

### Never
- ターミナル出力の直接パースに依存しない
- Claude のプロンプトパターンマッチに依存しない
- Backchannel メッセージファイルを Aidea 側で削除しない (ADR 0024)
- `.aidea/backchannels/` 直下に直接書かれたファイル (過去の flat 配置) をハンドラに通さない
- `.aidea/claude/{feature}.md` および `.aidea/claude/companions/<index>/instructions.md` の既存ファイルを上書きしない (ユーザ編集を保護)
- Aidea 側から共通プロンプトをハードコードで送信しない
- Companion 設定に起動プロンプト文字列を再び持たせない (v8 で指示書ファイルへ外部化済み、ADR 0022)
- `CLAUDE.md` を Aidea が自動改変しない
