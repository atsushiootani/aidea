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
last_updated: 2026-07-26
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

### 非表示タブの描画停止 (issue #273)

生かしたまま隠した端末が再描画を続けると、アイドル CPU が「開いているタブ数」に比例して増え続ける
(tmux のステータスバーや claude TUI のスピナー / カーソル点滅は、アイドル時も定期的に出力を吐くため)。
これを防ぐため、**非表示の端末は PTY 出力の受信・内部状態の更新は継続するが、画面への描画は行わない**。

| 状態 | PTY 受信 / 内部状態更新 | 画面描画 |
|---|---|---|
| 表示中 (ペインのアクティブタブ) | する | する |
| 非表示 (同一ペインの裏のタブ) | **する** (バッファは常に最新) | **しない** |

- **Always**: 非表示の端末が再表示された瞬間、最新の内容を一括で描画する。ユーザから見て「切り替えたら古い画面が一瞬見える」ことがあってはならない
- **Always**: 非表示中も PTY 出力の受信は止めない (実行中判定・トランスクリプト検出など、出力に依存する状態は非表示でも正しく更新され続ける)
- **Never**: 描画停止のために PTY 切断や tmux detach を行わない (バッファ生存の保証を壊すため)
- 効果: 端末描画のコストが「開いているタブ数」ではなく**表示中のペイン数**に比例する

本仕様は端末 View を共用する Claude セッション ([claude.md#状態](./claude.md#状態)) にも同様に適用される。

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
