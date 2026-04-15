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

## 自動起動シーケンス

```
1. zsh -c "cd '{projectRoot}' && exec zsh -l" で対話シェルを起動
2. +1.0s: send("claude\n") で Claude CLI を起動
3. +5.0s: send("{Backchannel 指示}\r") で .aidea/claude/aidea.md 読み込みを指示
4. companionPrompt があれば続けて送信
```

ADR 0008 により、非対話シェルから直接 `claude` を exec せず、**対話シェル内で `send()`** する。

## コンパニオンとの紐付け

`CompanionStore.activeSessionMap` が UUID → SessionID を保持し、本 Session と 1:1 対応する。
詳細は [../companions/companion.md](../companions/companion.md) を参照。
