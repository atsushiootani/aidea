---
title: Session 内部状態: Claude
description: ClaudeSessionState の状態 (companionPrompt / companionIndex / cached)・companionPrompt のセット経路・自動起動シーケンス・コンパニオン紐付け・Scene とレコメンドプロンプト・instructions.md ロード方式
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/sessions/terminal.md
  - docs/decisions/0008-no-claude-autostart.md
  - docs/decisions/0022-companion-instructions-as-files.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/claude.md
  - docs/specs/companions/recommend-mode.md
  - docs/specs/companions/companion.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-26
---

# Session 内部状態: Claude

`claude` Tool の Session は `ClaudeSessionState` として状態を保持する。
Terminal と同じ PTY ベースだが、起動後に `claude` CLI と Backchannel 指示を自動送信する。

Tool 仕様は [../tools/claude.md](../tools/claude.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。
Backchannel の詳細は [../backchannels/backchannel.md](../backchannels/backchannel.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `companionPrompt` | `String?` | 起動後 PTY に `send()` される文字列。v8 以降は `CompanionInstructions.loadCommand(for:)` で生成される固定パターン (`.aidea/claude/companions/<index>/instructions.md を読んで従ってね`) | ✅ |
| `companionIndex` | `Int?` | 紐付く Companion の index (0…8)。Scene 識別子 `claude:<index>` および `companionPrompt` 文字列の解決に使う。tmux セッション名の採番にも使う | ✅ |
| `isReady` | `Bool` | `autoStartClaude` のシーケンス完了 (claude 起動 + companionPrompt 送信 + Enter) を経て Frontchannel (`sendMessage`) を受け付け可能になったかどうか。`sendMessageWhenReady` が判定に使う。**tmux 再 attach 経路では autoStart をスキップしてただちに `true` に遷移する** | — |
| `isBusy` | `Bool` | PTY 出力が続いている (Claude がプロンプト処理中) 状態。Companion アイコンの実行中表示で参照 (issue #45)。判定ロジックは [../tools/claude.md#実行中判定-isbusy-issue-45](../tools/claude.md#実行中判定-isbusy-issue-45) を参照 | — |
| `cached` | `PersistentTerminalView?` (ObservationIgnored) | PTY + SwiftTerm 端末 View。Terminal と共用 | ✅ |
| `terminalView` | `PersistentTerminalView` (computed) | `cached` の lazy アクセサ | — |

`companionIndex` は `companionPrompt` と同じ経路でセットされる (新規起動時の `createSession` 直後 / スナップショット復元時の `apply()`)。Companion と紐付かない Claude セッションは発生しない想定 (`CompanionStore.activeSessionMap` の逆引きで一意に定まる)。

## `companionPrompt` のセット経路

`companionPrompt` は `autoStartClaude` が参照するため、**`terminalView` 生成前**に
セットされている必要がある。以下 2 経路のいずれかで設定される:

1. **新規起動**: `createSession` 直後に `state.companionPrompt = CompanionInstructions.loadCommand(for: index)` をセット
   (`CompanionView` / `AideaApp.activateCompanion` / `sendRecommendedPrompt`)
2. **スナップショット復元**: `WorkspaceSnapshotManager.apply()` が `CompanionStore.activeSessionMap`
   を走査し、bind 済みセッションに対して `ensureSession` で state を生成した上で同じヘルパで再注入
   (詳細は [../companions/companion.md#起動フロー-スナップショット復元時](../companions/companion.md))

どちらの経路でも、`terminalView` の lazy 生成時に `autoStartClaude` が参照する。

`CompanionInstructions` はパスとロードコマンド文字列の生成を集約するヘルパ。複数の呼び出し元で同じパターンを再生成しないよう、ハードコードを 1 箇所に閉じ込める ([ADR 0022](../../decisions/0022-companion-instructions-as-files.md))。

## 自動起動シーケンス

**自動起動シーケンス**とは、Claude セッションの端末生成時に一度だけ走る「端末起動 → `claude` 起動 → Companion 指示書の読み込み → 受付可能化」の一連の自動送信のこと。以降このプロジェクトで「自動起動シーケンス」と呼ぶものはこの手順を指す。

tmux の有無と既存セッションの有無で 3 経路に分岐する。判定は `terminalView` の lazy 生成時に行う。

| 経路 | 条件 | 起動コマンド | autoStartClaude |
|---|---|---|---|
| **A. tmux 新規** | tmux 検出 ✅ + 既存セッションなし | `exec <tmux> new-session -A -s aidea-claude-<idx>-<slug>-<hash> -c <dir>` | 実行する |
| **B. tmux 再 attach** | tmux 検出 ✅ + 既存セッション ✅ | 同上 (`-A` により attach される) | **スキップ** し `isReady=true` を即セット |
| **C. tmux 未インストール** | tmux 検出 ❌ | `cd '<dir>' && exec zsh -l` | 実行する |

### tmux セッション名

形式は `aidea-claude-<companionIndex>-<slug>-<hash>`。Terminal の `aidea-<slug>-<hash>-<instance>` と prefix で分離するため衝突しない。

- `<companionIndex>`: 紐付く Companion の index (0…8)。Companion ごとに別 tmux セッションを持つ
- `<slug>`: プロジェクトルートのディレクトリ名を小文字英数・ハイフン区切りに正規化
- `<hash>`: フルパスから生成した短いハッシュ (同名ディレクトリ区別用)

### 経路 A: 新規起動 (autoStartClaude)

```
1. tmux new-session で tmux セッションを新規作成 (zsh が起動)
2. +1.0s: send("claude\n") で Claude CLI を起動
3. +5.0s: send("{companionPrompt}") で Companion 指示書読み込みコマンドを送信 (v8 以降の固定パターン、ADR 0022)
4. +5.3s: send("\r") で submit させる
5. +6.0s: isReady=true。保留されていた `sendMessageWhenReady` の送信を順に flush
```

- ステップ 3-4 は分離して送る。Claude Code (Ink 製 TUI) は bracketed paste を有効にしており、本文と `\r` を一度に送ると `\r` も paste の一部とみなされ submit されないため、本文の入力処理が終わる間 (≈0.3s) を挟んでから `\r` を送る
- companionPrompt が空の場合はステップ 3-4 をスキップし、isReady は `+1.3s` でセット
- v8 以降のデフォルトは `".aidea/claude/companions/<index>/instructions.md を読んで従ってね"` (`CompanionInstructions.loadCommand(for:)` が生成)。Claude が `Read` ツールで本体を読みに行き、必要に応じて `aidea.md` / `speech.md` 等を段階的開示する
- ADR 0008 により、非対話シェルから直接 `claude` を exec せず、**対話シェル内で `send()`** する
- ハンドオフ / レコメンドプロンプトのように起動直後に Frontchannel へ送信したい場合は、固定 asyncAfter で待たず `sendMessageWhenReady` を使う。ready=false の間は内部で積んで `+6.0s` で flush される
- Frontchannel の `sendMessage` も**本文と `\r` を分離して送る** (本文送信 → ≈0.3s 後に `\r`)。理由はステップ 3-4 と同じ (bracketed paste で `\r` がペーストの一部とみなされ submit されない)。自動起動直後の flush や、ハンドオフ / inbox / スケジューラからの送信でも submit が確実に効くようにするため

### 経路 B: 再 attach (autoStartClaude スキップ)

tmux セッションが既存の場合、内部で `claude` TUI が既に起動 (Aidea 終了時に PTY だけ閉じられた状態) しているはず。ここで `send("claude\n")` を再送すると **TUI の入力欄に "claude" という文字列が入力されてしまう** ため、autoStart シーケンスをまるごとスキップする。

```
1. tmux new-session -A で既存セッションに attach (zsh プロンプトではなく claude TUI が表示される)
2. isReady=true を即座にセット (Frontchannel からの sendMessage を受け付け可能)
```

- `companionPrompt` は **再送しない**。再 attach 時の Claude TUI には既に同じ Companion の起動時指示が読み込まれている前提
- ハンドオフ受信などで `sendMessageWhenReady` を経由する場合も、isReady=true なので即時送信される
- 判定は tmux 起動コマンド組み立て時点で `tmux has-session -t <name>` を実行し、exit code で判定する

### 経路 C: tmux なし (フォールバック)

tmux が探索パス (`/opt/homebrew/bin/tmux` → `/usr/local/bin/tmux` → `/usr/bin/tmux`) のいずれにも見つからない場合は従来通り `cd <dir> && exec zsh -l` で直接起動し、経路 A と同じ autoStartClaude を実行する。Aidea 終了で claude プロセスは消滅する (永続化なし)。



`CompanionStore.activeSessionMap` が UUID → SessionID を保持し、本 Session と 1:1 対応する。
詳細は [../companions/companion.md](../companions/companion.md) を参照。

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `companionIndex` | `currentScene()` |
|---|---|
| `0` | `"claude:0"` |
| `1` | `"claude:1"` |
| … | … |
| `8` | `"claude:8"` |
| `nil` | `nil` (レコメンド無反応) |

- Scene キーは Companion ごとに分かれるため、**Companion 毎に別レコメンドプロンプトを持てる** (例: テスト担当 Companion 2 なら `"テストして"`、レビュー担当 Companion 4 なら `"差分をレビューして"`)。
- 初期値の `defaultCompanionIndex` は自 Companion の index に一致させる (例: `claude:5` なら `5`)。これにより Cmd+Enter 起動時にそのセッション自身の Companion が最初に選択される (詳細は [../companions/recommend-mode.md](../companions/recommend-mode.md))。
- 初期プロンプトは空配列 (`[]`)。ユーザは ClaudeSessionView 下部の `ScenePromptsEditorView` で Companion 固有のプロンプトを追加できる。
