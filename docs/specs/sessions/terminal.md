---
title: Session 内部状態: Terminal
description: TerminalSessionState の PTY + SwiftTerm キャッシュ方式・tmux による PTY プロセス永続化・PaneView ZStack による状態維持・Scene とレコメンドプロンプト
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/architecture.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/terminal.md
  - docs/specs/companions/recommend-mode.md
  - docs/specs/aspects/persistence.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-06
---

# Session 内部状態: Terminal

`terminal` Tool の Session は `TerminalSessionState` (`@Observable`) として状態を保持する。
**ペイン移動で PTY バッファを含む状態が失われない** ことを保証する。

Tool 仕様は [../tools/terminal.md](../tools/terminal.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| プロパティ | 型 | 用途 | ペイン移動で保持 |
|---|---|---|---|
| `cached` | `PersistentTerminalView?` (ObservationIgnored) | 遅延生成した PTY + SwiftTerm 端末 View。**同一インスタンスを使い回すことで PTY バッファが保たれる** | ✅ |
| `terminalView` | `PersistentTerminalView` (computed) | `cached` の lazy アクセサ。未生成ならここで生成 | — |

## ペイン移動で状態を失わない仕組み

- `PaneView` が全タブを ZStack で常時レンダリング (`opacity(0)` + `allowsHitTesting(false)` で非アクティブを隠す)
- NSView が superview から外れないので **PTY バッファが常に生存** する
- 詳細は [../architecture.md#ui-レイアウトのアーキ上の注意](../architecture.md#ui-レイアウトのアーキ上の注意) を参照

## 永続化

### tmux による PTY プロセス永続化

tmux が利用可能な場合 (探索順: `/opt/homebrew/bin/tmux` → `/usr/local/bin/tmux` → `/usr/bin/tmux`)、PTY の内側で名前付き tmux セッションを自動起動する。

| 項目 | 詳細 |
|---|---|
| セッション名 | `aidea-<project-slug>-<path-hash>-<instance>` 形式。`project-slug` はプロジェクトルートのディレクトリ名を小文字英数・ハイフン区切りに正規化したもの。`path-hash` はフルパスから生成した短いハッシュ (同名ディレクトリを区別するため) |
| 起動コマンド | `exec <tmux> new-session -A -s <name> -c <dir>` — 同名セッションが存在すれば attach、なければ新規作成 |
| Aidea 終了時 | PTY (tmux クライアント) が閉じられるが、tmux サーバは生存しシェルプロセスが継続する |
| 再起動後の再接続 | Aidea 再起動後に同じ `instance` 番号でターミナルタブを作ると (`nextSessionInstance` は起動時に既存タブがなければ 0 から採番し直す)、同名の tmux セッションに自動 attach する |

tmux が見つからない場合は既存どおり `cd <dir> && exec zsh -l` で直接起動する (フォールバック)。

### PTY バッファ

PTY バッファ自体は揮発性。ただし tmux セッションが生存していれば、tmux のスクロールバックバッファに出力履歴が保持される。タブを閉じる (`Cmd+W`) とターミナルプロセスも終了する (tmux セッションが破棄される)。

## Scene とレコメンドプロンプト

`SessionState` プロトコル ([../frontchannels/scene.md](../frontchannels/scene.md)) を実装し、Cmd+Enter でのレコメンド送信に対応する。

| `currentScene()` | 場面 |
|---|---|
| `"terminal"` | Terminal ツール全体 (mode 分岐なし) |

- 初期プロンプトは空配列 (`[]`)。ユーザは TerminalSessionView 下部の `ScenePromptsEditorView` から追加できる。
- `defaultCompanionIndex` 初期値は `0`。
