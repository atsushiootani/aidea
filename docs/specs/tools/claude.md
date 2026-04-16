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
| `ClaudeSessionState` | PTY 起動 + claude 自動送信 + Backchannel 指示送信 |
| `PersistentTerminalView` | Terminal と共用 |
| `ClaudeSessionView` | NSViewRepresentable ラッパ（Terminal と同構造） |

---

## 起動フロー

```
1. zsh -c "cd '{projectRoot}' && exec zsh -l" で対話シェルを起動
2. 1 秒後: send("claude\n") で claude を起動
3. 5 秒後: send("{Backchannel 指示}\r") で aidea.md 読み込みを指示
```

### 自動送信のタイミング

| ステップ | 遅延 | 内容 |
|---------|------|------|
| zsh 起動 | 0s | PTY プロセス開始 |
| claude 送信 | +1.0s | `claude\n` を PTY に送信 |
| companionPrompt 送信 | +5.0s | コンパニオンの `initialPrompt` を PTY に送信 |

- `send()` は PTY にキー入力を送るため、対話シェル内での手入力と同等
- ADR 0008 の非対話シェル問題を回避
- companionPrompt が空の場合はステップ 3 をスキップ

---

## Backchannel 連携

コンパニオンの `initialPrompt` が `.aidea/claude/` 配下のファイルを読むよう指示することで Backchannel 機能を有効化する。デフォルトの `initialPrompt` は `".aidea/claude/aidea.md と .aidea/claude/speech.md を読んで従ってね"`。

1. BackchannelSetup が `.aidea/claude/aidea.md` と `speech.md` を Bundle からコピー済み
2. companionPrompt 送信により Claude がこれらのファイルを読む
3. 以降 Claude が `.aidea/backchannels/speech-{timestamp}.txt` にレスポンス要約を書き出す
4. Aidea の SpeechWatcher が検知して VOICEVOX で読み上げ

詳細は [backchannels/voicevox.md](../backchannels/voicevox.md) を参照。

---

## キーボードショートカット

| キー | アクション |
|------|-----------|
| `Cmd+Option+8` | Claude ツールにフォーカス（複数あれば循環） |

---

## 境界

### Always
- 対話シェル内で `send()` により claude を起動する（非対話シェルからの exec ではない）
- Backchannel 指示はコンパニオンの `initialPrompt` 経由で `.aidea/claude/*.md` を読むよう Claude に伝える形で行う
- PersistentTerminalView は Terminal ツールと共用する

### Never
- 非対話シェルから直接 claude を exec しない（ADR 0008）
- claude の起動完了を出力パースで検知しない（固定遅延で対応）
