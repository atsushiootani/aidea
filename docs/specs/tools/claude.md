---
title: Tool 仕様: Claude
description: Claude Code を自動起動し Backchannel で Aidea と連携するターミナル Tool の仕様
derived_from:
  - docs/decisions/0008-no-claude-autostart.md
  - docs/decisions/0017-alternate-screen-scroll-handling.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/window/
  - docs/specs/backchannels/backchannel.md
syncs_with:
  - docs/specs/sessions/claude.md
  - docs/specs/aspects/keybindings.md
  - docs/specs/companions/companion.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-01
---

# Tool 仕様: Claude

Claude Code を自動起動し、Backchannel で Aidea と連携するターミナル Tool。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/claude.md](../sessions/claude.md) を参照。
共通 UI 規約は [sessions/ui-rules.md](../sessions/ui-rules.md) と [window/](../window/README.md) を参照。
Backchannel の詳細は [backchannels/backchannel.md](../backchannels/backchannel.md) を参照。

---

## 概要

- Terminal ツールと同じ SwiftTerm ベースの PTY ターミナル
- **複数インスタンス可** — Window 内で複数の Claude セッションを開ける
- ターミナル起動後に `claude` コマンドと Backchannel 指示を自動送信
- 読み上げ等の Backchannel 機能が自動的に有効になる

---

## Terminal ツールとの違い

| 項目 | Terminal | Claude |
|------|----------|--------|
| PTY 起動 | する | する |
| claude 自動起動 | しない | する |
| Backchannel 指示送信 | しない | する |
| アイコン | `apple.terminal` | `bubble.left.and.text.bubble.right` |
| 表示名 | Terminal | Claude |

---

## 実装コンポーネント

| コンポーネント | 役割 |
|---------------|------|
| `ClaudeSessionState` | PTY 起動 + claude 自動送信 + Backchannel 指示送信 + **`isBusy` / `isSpeaking` 状態公開** (issue #45) |
| `PersistentTerminalView` | Terminal と共用 |
| `ClaudeSessionView` | NSViewRepresentable ラッパ（Terminal と同構造） |

---

## 起動フロー

```
1. zsh -c "cd '{projectRoot}' && exec zsh -l" で対話シェルを起動
2. 1 秒後: send("claude\n") で claude を起動
3. 5 秒後: send("{companionPrompt}") で Companion 指示書読み込みコマンドを送信
4. 5.3 秒後: send("\r") で submit
5. 6.0 秒後: isReady フラグを true にセット (Frontchannel からの sendMessage が安全に使える状態)
```

### 自動送信のタイミング

| ステップ | 遅延 | 内容 |
|---------|------|------|
| zsh 起動 | 0s | PTY プロセス開始 |
| claude 送信 | +1.0s | `claude\n` を PTY に送信 |
| companionPrompt 送信 | +5.0s | `CompanionInstructions.loadCommand(for:)` が生成した固定パターン文字列 (`.aidea/claude/companions/<index>/instructions.md を読んで従ってね`) を PTY に送信 |
| Enter 送信 | +5.3s | `\r` を送って submit させる |
| isReady=true | +6.0s | Frontchannel (sendMessage) を受け付け可能とマーク。待機中の送信はこのタイミングで実行される |

- `send()` は PTY にキー入力を送るため、対話シェル内での手入力と同等
- ADR 0008 の非対話シェル問題を回避
- companionPrompt が空の場合はステップ 3-4 をスキップし、isReady は `+1.3s` でセット
- 本文と `\r` を分離するのは、Claude Code (Ink 製 TUI) が bracketed paste を有効にしており、両者を一度に送ると `\r` も paste の一部とみなされ submit されないため。本文の入力処理が終わる間 (≈0.3s) を挟む
- v8 以降、Aidea が送るのは固定パターン文字列のみ。Claude が Read ツールで `instructions.md` 本文を取りに行く (ADR 0022)。Claude 側は `instructions.md` 冒頭から `.aidea/claude/aidea.md` / `speech.md` / `handoff.md` 等を段階的に読み込む

---

## Backchannel 連携

コンパニオンの `instructions.md` 内で `.aidea/claude/` 配下の機能ファイルを参照することで Backchannel 機能が有効化される (機能宣言チェーン、ADR 0022)。Aidea が起動時に送るのは `CompanionInstructions.loadCommand(for:)` が生成する固定パターン文字列のみで、本文は Claude が Read ツール経由でファイルから取得する。

1. BackchannelSetup が `.aidea/claude/aidea.md` / `speech.md` / `handoff.md` と `companions/<0..8>/instructions.md` を Bundle からコピー済み (既存ファイルは上書きしない)
2. companionPrompt 送信により Claude が `instructions.md` を読み込む
3. `instructions.md` の参照行に従って Claude が `aidea.md` / `speech.md` / `handoff.md` 等を段階的に読み込む (参照しない Companion はその機能を持たない)
4. 以降 Claude が `.aidea/backchannels/<companion-index>/speech-{timestamp}.txt` や `handoff-{timestamp}.json` にメッセージを書き出す (ADR 0024)
5. Aidea の SpeechWatcher / HandoffWatcher が検知して VOICEVOX 読み上げ / 他 Companion への配送を行う

詳細は [backchannels/voicevox.md](../backchannels/voicevox.md) / [backchannels/handoff.md](../backchannels/handoff.md) を参照。

---

## 実行中判定 `isBusy` (issue #45)

`ClaudeSessionState` に `@Observable` な `isBusy: Bool` を公開する。Companion アイコンの表情切替 ([../companions/companion.md#表情・状態表示-issue-45](../companions/companion.md#表情・状態表示-issue-45)) が外部から参照する。

### 判定ロジック

- **true にする**: PTY に `send` したタイミング。`Frontchannel.sendMessage` / `autoStartClaude` が PTY に書き込んだ直後に `markBusy()` で明示的にセットする (出力を待たずに UI を考え中表示に切り替えるため)
- **初期タイマー (3.0s)**: `markBusy()` は `busySendDebounceInterval` (3.0s) のタイマーをセットする。Claude API のレイテンシで最初の出力が来るまでの間も busy=true を維持するための猶予期間
- **タイマー延長 (0.5s)**: busy 中に PTY 出力が来たらデバウンスタイマーを `busyDebounceInterval` (0.5s) に再セットする (応答ストリーミング中は延長され続けて busy 維持)
- **false にする**: busy 中に PTY 出力が **0.5 秒** 途切れたら `isBusy = false` に戻す。send から 3.0s 以内に出力が来なかった場合も同様

> **Never**: PTY 出力を観測しただけで `isBusy = true` にはしない。Claude CLI はアイドル時もカーソル点滅 / 定期再描画で出力を出すため、「出力観測 = busy」にすると常時 busy になる。send ベースで true にすることで「ユーザ/Aidea が Claude に仕事を投げた期間」のみを busy と判定する。

- 出力静止判定の 0.5s は `claude` CLI が tool 実行中やテキストストリーミング中に細かく出力することを考慮した体感値
- 初期猶予の 3.0s は Claude API のレイテンシ (通常 1〜3s 程度) をカバーする体感値。実運用で調整が必要な場合は `busySendDebounceInterval` を変更する

### ライフサイクル

| タイミング | `isBusy` | 遷移理由 |
|---|---|---|
| `ClaudeSessionState` 初期化直後 | `false` | send 未実施 |
| 自動起動シーケンス (claude / companionPrompt / Enter send) | 各 send 直後に `true` | `markBusy()` (3.0s タイマー) |
| TUI 初期描画中〜 isReady | `true` 維持 | 応答出力で 0.5s タイマーに切り替え延長 |
| 入力待ちプロンプト表示 (起動後の初回アイドル) | 0.5s 静止後 `false` | タイマー満了 |
| ユーザが `Cmd+Enter` でプロンプト送信 | 送信直後 `true` | `markBusy()` (3.0s タイマー) |
| Claude の応答ストリーミング中 | `true` 維持 | 応答出力で 0.5s タイマーに切り替え延長 |
| 応答完了 → 入力待ちプロンプト表示 | 0.5s 静止後 `false` | タイマー満了 |
| PTY 終了時 (`exitCode != nil`) | `false` | (アイドル扱い) |

### 外部参照箇所

| 参照元 | 用途 |
|---|---|
| `CompanionView.companionIcon(_:)` | 「実行中」状態判定でアイコンを `companion-N-thinking` + `ellipsis.bubble` に切り替える |

**Never**: `isBusy` をターミナル出力の文字列パース (「> 」「✻」など特定トークン検知) で判定しない。出力静止ベースの単純判定に留める ([ADR 0008](../../decisions/0008-no-claude-autostart.md) の思想踏襲)。

---

## 読み上げ中判定 `isSpeaking` (issue #45)

`ClaudeSessionState` に computed な `isSpeaking: Bool` を公開する。状態実体は持たず、`SpeechQueue.currentlySpeakingIndex == companionIndex` を返す薄い facade。Companion アイコンの表情切替 ([../companions/companion.md#表情・状態表示-issue-45](../companions/companion.md#表情・状態表示-issue-45)) が `isBusy` と対称に read できるよう揃える位置づけ。

### 状態源

- **SSoT**: `SpeechQueue.currentlySpeakingIndex: Int?` ([../backchannels/voicevox.md](../backchannels/voicevox.md))
- **注入**: Claude セッション生成 / 復元時に `state.speechQueue = speechState.queue` で weak 参照を持たせる (`AideaApp.activateCompanion` / `sendRecommendedPrompt` / `dispatchHandoff` / `CompanionView.launchCompanion` / `WorkspaceSnapshotManager.apply`)
- **tracking**: `SpeechQueue` 自身が `@Observable` なので、`isSpeaking` を読むスコープに観測が自動伝播する (ClaudeSessionState に別途 stored な state を持たせない)

### 外部参照箇所

| 参照元 | 用途 |
|---|---|
| `CompanionView.companionIcon(_:)` | 「読み上げ中」状態判定でアイコンを `companion-N-smile` + `heart.fill` に切り替える |

---

## キーボードショートカット

### グローバル

| キー | アクション |
|------|-----------|
| `Cmd+Option+8` | Claude ツールにフォーカス（複数あれば循環） |

### ターミナル内操作（Aidea が NSEvent モニターで変換）

| キー/操作 | 条件 | 送信されるキー | アクション |
|----------|------|-------------|-----------|
| ホイールスクロール上 | トランスクリプトモード時 | `Ctrl+U` | 半ページ上スクロール |
| ホイールスクロール下 | トランスクリプトモード時 | `Ctrl+D` | 半ページ下スクロール |
| ホイールクリック | 常時 | `Ctrl+O` | 通常モード ↔ トランスクリプトモードのトグル |

トランスクリプトモードの判定は、ターミナルバッファの最下行に `"transcript"` を含むかどうかで行う。
詳細は [ADR 0017](../../decisions/0017-alternate-screen-scroll-handling.md) を参照。

---

## 境界

### Always
- 対話シェル内で `send()` により claude を起動する（非対話シェルからの exec ではない）
- Backchannel 指示はコンパニオンの `instructions.md` 経由で `.aidea/claude/*.md` を読むよう Claude に伝える形で行う (v8 以降、ADR 0022)
- PersistentTerminalView は Terminal ツールと共用する

### Never
- 非対話シェルから直接 claude を exec しない（ADR 0008）
- claude の起動完了を出力パースで検知しない（固定遅延で対応）
