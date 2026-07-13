---
title: Session 内部状態: Terminal
description: Terminal セッションが保持する状態 (PTY + 端末 View)・tmux による PTY プロセス永続化・ペイン移動での状態維持・Scene とレコメンドプロンプト
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/architecture.md
  - docs/specs/frontchannels/scene.md
syncs_with:
  - docs/specs/tools/terminal.md
  - docs/specs/companions/recommend-mode.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# Session 内部状態: Terminal

`terminal` Tool の Session が保持する状態。
**ペイン移動で PTY バッファを含む状態が失われない** ことを保証する。

Tool 仕様は [../tools/terminal.md](../tools/terminal.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。

## 状態

| 状態 | 用途 | ペイン移動で保持 |
|---|---|---|
| 端末 View | 遅延生成した PTY + SwiftTerm 端末 View。**同一インスタンスを使い回すことで PTY バッファが保たれる** | ✅ |

## ペイン移動で状態を失わない仕組み

- 非アクティブなタブも View を生かしたまま隠す方式 (ペイン内で全タブを重ねてレンダリングし、非アクティブを透明化 + 操作無効化)
- View が画面階層から外れないので **PTY バッファが常に生存** する
- 詳細は [../architecture.md#ui-レイアウトのアーキ上の注意](../architecture.md#ui-レイアウトのアーキ上の注意) を参照

## 永続化

### tmux による PTY プロセス永続化

tmux が利用可能な場合 (探索順: `/opt/homebrew/bin/tmux` → `/usr/local/bin/tmux` → `/usr/bin/tmux`)、PTY の内側で名前付き tmux セッションを自動起動する。

| 項目 | 詳細 |
|---|---|
| セッション名 | `aidea-<project-slug>-<path-hash>-<instance>` 形式。`project-slug` はプロジェクトルートのディレクトリ名を小文字英数・ハイフン区切りに正規化したもの。`path-hash` はフルパスから生成した短いハッシュ (同名ディレクトリを区別するため)。Claude セッションは prefix `aidea-claude-` を使い ([sessions/claude.md#tmux-セッション名](./claude.md#tmux-セッション名))、衝突しない |
| 起動コマンド | `exec <tmux> new-session -A -s <name> -c <dir>` — 同名セッションが存在すれば attach、なければ新規作成 |
| Aidea 終了時 | PTY (tmux クライアント) が閉じられるが、tmux サーバは生存しシェルプロセスが継続する |
| 再起動後の再接続 | Aidea 再起動後に同じ instance 番号でターミナルタブを作ると (instance 番号は起動時に既存タブがなければ 0 から採番し直す)、同名の tmux セッションに自動 attach する |

tmux が見つからない場合は既存どおり `cd <dir> && exec zsh -l` で直接起動する (フォールバック)。

tmux の探索・起動コマンドの組み立て・既存セッション判定の仕組みは Terminal と Claude セッションで共用し、同じ実装を参照する。

### PTY バッファ

PTY バッファ自体は揮発性。ただし tmux セッションが生存していれば、tmux のスクロールバックバッファに出力履歴が保持される。タブを閉じる (`Cmd+W`) とターミナルプロセスも終了する (tmux セッションが破棄される)。

## Scene とレコメンドプロンプト

セッション共通の仕組み ([../frontchannels/scene.md](../frontchannels/scene.md)) で、Cmd+Enter でのレコメンド送信に対応する。

| Scene 識別子 | 場面 |
|---|---|
| `"terminal"` | Terminal ツール全体 (mode 分岐なし) |

- 初期プロンプトは空。ユーザは Terminal ツール下部のプロンプト編集エリアから追加できる。
- 既定の Companion は index 0。
