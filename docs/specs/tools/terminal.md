# Tool 仕様: Terminal

ターミナル (PTY) を提供する Tool。純粋なシェル環境のみを起動する。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/terminal.md](../sessions/terminal.md) を参照。
共通 UI 規約は [sessions/ui-rules.md](../sessions/ui-rules.md) と [window/](../window/README.md) を参照。

---

## 概要

- SwiftTerm (`LocalProcessTerminalView`) ベースの PTY ターミナル
- **複数インスタンス可** — Window 内で複数の Terminal セッションを開ける
- `WorkspaceState.projectRoot` を初期ディレクトリとして `zsh -l` を起動
- 対話シェル (`exec zsh -l`) で起動（ADR 0008 参照）
- `claude` の自動起動は**行わない** — 純粋なシェル環境のみ

---

## 実装コンポーネント

| コンポーネント | 役割 |
|---------------|------|
| `TerminalSessionState` | PTY の生成・キャッシュ、フォーカス管理 |
| `PersistentTerminalView` | SwiftTerm の LocalProcessTerminalView 拡張。ペイン移動時のバッファ消失防止 |
| `TerminalSessionView` | NSViewRepresentable ラッパ |

---

## 起動フロー

```
1. zsh -c "cd '{projectRoot}' && exec zsh -l" で対話シェルを起動
2. 環境変数: TERM=xterm-256color, SHELL=/bin/zsh
3. ユーザーが手動でコマンドを実行
```

---

## PersistentTerminalView

ペイン間移動時に NSView が一時的に detach される（superview = nil, bounds = 0）際、
SwiftTerm がバッファをクリアしてしまう問題を回避するサブクラス。

- `layout()` / `setFrameSize()` / `setBoundsSize()` で bounds < 10pt のときスキップ
- PTY プロセスは初回アクセス時に 1 回だけ起動し、以降はキャッシュを返す

---

## キーボードショートカット

| キー | アクション |
|------|-----------|
| `Cmd+Option+7` | Terminal ツールにフォーカス（複数あれば循環） |

---

## 境界

### Always
- 対話シェル (`exec zsh -l`) で起動する
- PTY は初回生成後にキャッシュし、タブ切替・ペイン移動で再生成しない

### Never
- Terminal ツールから `claude` を自動起動しない（Claude ツールの責務）
- 非対話シェルから直接プロセスを exec しない（ADR 0008）
