---
title: Session 内部状態: Claude
description: Claude Tool の Session 状態 (companionPrompt / companionIndex / ターミナルビューキャッシュ)・初期プロンプトのセット経路・自動起動シーケンス・コンパニオン紐付け・Scene とレコメンドプロンプト・instructions.md ロード方式
derived_from:
  - docs/specs/sessions/ui-rules.md
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
last_updated: 2026-04-24
---

# Session 内部状態: Claude

`claude` Tool の Session 状態を管理する。PTY ベースで claude CLI を起動し、Backchannel 指示を自動送信する。
Terminal と同じ PTY ベースだが、起動後に `claude` CLI と Backchannel 指示を自動送信する。

Tool 仕様は [../tools/claude.md](../tools/claude.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。
Backchannel の詳細は [../backchannels/backchannel.md](../backchannels/backchannel.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `companionPrompt` | `String?` | 起動後 PTY に送信される文字列。v8 以降は `.aidea/claude/companions/<index>/instructions.md を読んで従ってね` の固定パターン | ✅ |
| `companionIndex` | `Int?` | 紐付く Companion の index (0…8)。Scene 識別子 `claude:<index>` および `companionPrompt` 文字列の解決に使う | ✅ |
| `isReady` | `Bool` | 自動起動シーケンス完了 (claude 起動 + companionPrompt 送信 + Enter) を経て Frontchannel メッセージ送信を受け付け可能になったかどうか | — |
| `isBusy` | `Bool` | PTY 出力が続いている (Claude がプロンプト処理中) 状態。Companion アイコンの実行中表示で参照 (issue #45)。判定ロジックは [../tools/claude.md#実行中判定-isbusy-issue-45](../tools/claude.md#実行中判定-isbusy-issue-45) を参照 | — |
| `cached` | `PersistentTerminalView?` (ObservationIgnored) | PTY + SwiftTerm 端末 View。Terminal と共用 | ✅ |
| `terminalView` | `PersistentTerminalView` (computed) | `cached` の lazy アクセサ | — |

`companionIndex` は `companionPrompt` と同じ経路でセットされる (新規起動時 / スナップショット復元時)。Companion と紐付かない Claude セッションは発生しない想定 (コンパニオンマップの逆引きで一意に定まる)。

## `companionPrompt` のセット経路

`companionPrompt` は `autoStartClaude` が参照するため、**`terminalView` 生成前**に
セットされている必要がある。以下 2 経路のいずれかで設定される:

1. **新規起動**: セッション作成直後に `companionPrompt` を固定パターン文字列にセット
   (コンパニオンビュー / アプリのコンパニオン有効化処理 / レコメンドプロンプト送信の各経路)
2. **スナップショット復元**: ワークスペース復元処理がコンパニオンマップを走査し、
   bind 済みセッションに同じ固定パターン文字列を再注入
   (詳細は [../companions/companion.md#起動フロー-スナップショット復元時](../companions/companion.md))

どちらの経路でも、`terminalView` の lazy 生成時に `autoStartClaude` が参照する。

パスとロードコマンド文字列の生成は専用ヘルパに集約し、複数の呼び出し元で同じパターンを再生成しないようハードコードを 1 箇所に閉じ込める ([ADR 0022](../../decisions/0022-companion-instructions-as-files.md))。

## 自動起動シーケンス

```
1. zsh -c "cd '{projectRoot}' && exec zsh -l" で対話シェルを起動
2. +1.0s: send("claude\n") で Claude CLI を起動
3. +5.0s: send("{companionPrompt}") で Companion 指示書読み込みコマンドを送信 (v8 以降の固定パターン、ADR 0022)
4. +5.3s: send("\r") で submit させる
5. +6.0s: isReady=true。保留されていた送信を順に flush
```

- ステップ 3-4 は分離して送る。Claude Code (Ink 製 TUI) は bracketed paste を有効にしており、本文と `\r` を一度に送ると `\r` も paste の一部とみなされ submit されないため、本文の入力処理が終わる間 (≈0.3s) を挟んでから `\r` を送る
- companionPrompt が空の場合はステップ 3-4 をスキップし、isReady は `+1.3s` でセット
- v8 以降のデフォルトは `".aidea/claude/companions/<index>/instructions.md を読んで従ってね"` の固定パターン。Claude が `Read` ツールで本体を読みに行き、必要に応じて `aidea.md` / `speech.md` 等を段階的開示する
- ADR 0008 により、非対話シェルから直接 `claude` を exec せず、**対話シェル内で `send()`** する
- ハンドオフ / レコメンドプロンプトのように起動直後に Frontchannel へ送信したい場合は、固定遅延ではなく ready 待ちキューに積んで送信する。ready=false の間は内部で保留して `+6.0s` で flush される

## コンパニオンとの紐付け

コンパニオンマップが UUID → SessionID を保持し、本 Session と 1:1 対応する。
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
