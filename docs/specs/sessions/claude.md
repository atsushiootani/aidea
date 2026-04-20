---
title: Session 内部状態: Claude
description: ClaudeSessionState の状態 (companionPrompt / cached)・companionPrompt のセット経路・自動起動シーケンス・コンパニオン紐付け
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/decisions/0008-no-claude-autostart.md
syncs_with:
  - docs/specs/tools/claude.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-20
---

# Session 内部状態: Claude

`claude` Tool の Session は `ClaudeSessionState` (`@Observable`) として状態を保持する。
Terminal と同じ PTY ベースだが、起動後に `claude` CLI と Backchannel 指示を自動送信する。

Tool 仕様は [../tools/claude.md](../tools/claude.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。
Backchannel の詳細は [../backchannels/backchannel.md](../backchannels/backchannel.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `companionPrompt` | `String?` | コンパニオンの `initialPrompt`。起動後 `send()` される | ✅ |
| `cached` | `PersistentTerminalView?` (ObservationIgnored) | PTY + SwiftTerm 端末 View。Terminal と共用 | ✅ |
| `terminalView` | `PersistentTerminalView` (computed) | `cached` の lazy アクセサ | — |

## `companionPrompt` のセット経路

`companionPrompt` は `autoStartClaude` が参照するため、**`terminalView` 生成前**に
セットされている必要がある。以下 2 経路のいずれかで設定される:

1. **新規起動**: `createSession` 直後に `state.companionPrompt = config.initialPrompt`
   (`CompanionView` / `AideaApp.activateCompanion` / `sendRecommendedPrompt`)
2. **スナップショット復元**: `WorkspaceSnapshotManager.apply()` が `CompanionStore.activeSessionMap`
   を走査し、bind 済みセッションに対して `ensureSession` で state を生成した上で再注入
   (詳細は [../companions/companion.md#起動フロー-スナップショット復元時](../companions/companion.md))

どちらの経路でも、`terminalView` の lazy 生成時に `autoStartClaude` が参照する。

## 自動起動シーケンス

```
1. zsh -c "cd '{projectRoot}' && exec zsh -l" で対話シェルを起動
2. +1.0s: send("claude\n") で Claude CLI を起動
3. +5.0s: send("{companionPrompt}") でコンパニオンの initialPrompt 本文を送信
4. +5.3s: send("\r") で submit させる
```

- ステップ 3-4 は分離して送る。Claude Code (Ink 製 TUI) は bracketed paste を有効にしており、本文と `\r` を一度に送ると `\r` も paste の一部とみなされ submit されないため、本文の入力処理が終わる間 (≈0.3s) を挟んでから `\r` を送る
- companionPrompt が空の場合はステップ 3-4 をスキップ
- デフォルトの initialPrompt は `".aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね"`
- ADR 0008 により、非対話シェルから直接 `claude` を exec せず、**対話シェル内で `send()`** する。

## コンパニオンとの紐付け

`CompanionStore.activeSessionMap` が UUID → SessionID を保持し、本 Session と 1:1 対応する。
詳細は [../companions/companion.md](../companions/companion.md) を参照。
