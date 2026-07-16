---
title: Session 内部状態: Claude
description: Claude セッションが保持する状態 (起動時指示コマンド / Companion index / 端末 View)・そのセット経路・自動起動シーケンス・コンパニオン紐付け・Scene とレコメンドプロンプト・instructions.md ロード方式
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
last_updated: 2026-07-13
---

# Session 内部状態: Claude

`claude` Tool の Session が保持する状態 (Claude セッション状態)。
Terminal と同じ PTY ベースだが、起動後に `claude` CLI と Backchannel 指示を自動送信する。

Tool 仕様は [../tools/claude.md](../tools/claude.md) を、共通 UI ルールは [ui-rules.md](./ui-rules.md) を参照。
Backchannel の詳細は [../backchannels/backchannel.md](../backchannels/backchannel.md) を参照。

## 状態

| 状態 | 用途 | ペイン移動で保持 |
|---|---|---|
| 起動時指示コマンド | [自動起動シーケンス](#自動起動シーケンス)で PTY に送信される文字列。v8 以降は固定パターン (`.aidea/claude/companions/<index>/instructions.md を読んで従ってね`) を生成して使う ([ADR 0022](../../decisions/0022-companion-instructions-as-files.md)) | ✅ |
| Companion index | 紐付く Companion の index (0…8)。Scene 識別子 `claude:<index>`、起動時指示コマンドのパス解決、tmux セッション名の採番に使う | ✅ |
| 受付可能 | 自動起動シーケンス完了 (claude 起動 + 起動時指示コマンド送信 + Enter) を経て、Frontchannel からの送信を受け付け可能になったかどうか。保留付き送信 (後述) が判定に使う。**tmux 再 attach 経路では自動起動シーケンスをスキップしてただちに受付可能になる** | — |
| 実行中 | PTY 出力が続いている (Claude がプロンプト処理中) 状態。Companion アイコンの実行中表示で参照 (issue #45)。判定ロジックは [../tools/claude.md#実行中判定-isbusy-issue-45](../tools/claude.md#実行中判定-isbusy-issue-45) を参照 | — |
| 端末 View | 遅延生成した PTY + 端末 View。Terminal と共用 ([terminal.md#状態](./terminal.md#状態)) | ✅ |

Companion index は起動時指示コマンドと同じ経路でセットされる (新規起動時のセッション生成直後 / スナップショット復元時)。Companion と紐付かない Claude セッションは発生しない想定 (Companion 管理が保持する Companion → Session の対応表の逆引きで一意に定まる)。

## 起動時指示コマンドのセット経路

起動時指示コマンドは自動起動シーケンスが参照するため、**端末 View の生成前**に
セットされている必要がある。以下 2 経路のいずれかで設定される:

1. **新規起動**: セッション生成直後に、固定パターンの読み込みコマンドを生成してセットする
   (Companion アイコンからの起動 / Companion のアクティブ化 / レコメンドプロンプト送信のいずれの起点でも同じ)
2. **スナップショット復元**: スナップショット復元処理が Companion → Session の対応表を走査し、
   bind 済みセッションの状態を用意した上で同じ手順で再注入する
   (詳細は [../companions/companion.md#起動フロー-スナップショット復元時](../companions/companion.md))

どちらの経路でも、端末 View の遅延生成時に自動起動シーケンスが参照する。

指示書のパスと読み込みコマンド文字列の生成は 1 箇所に集約し、複数の呼び出し元で同じパターンを再生成しない ([ADR 0022](../../decisions/0022-companion-instructions-as-files.md))。

## 自動起動シーケンス

**自動起動シーケンス**とは、Claude セッションの端末生成時に一度だけ走る「端末起動 → `claude` 起動 → Companion 指示書の読み込み → 受付可能化」の一連の自動送信のこと。以降このプロジェクトで「自動起動シーケンス」と呼ぶものはこの手順を指す。

tmux の有無と既存セッションの有無で 3 経路に分岐する。判定は端末 View の遅延生成時に行う。

| 経路 | 条件 | 起動コマンド | 自動起動シーケンス |
|---|---|---|---|
| **A. tmux 新規** | tmux 検出 ✅ + 既存セッションなし | `exec <tmux> new-session -A -s aidea-claude-<idx>-<slug>-<hash> -c <dir>` | 実行する |
| **B. tmux 再 attach** | tmux 検出 ✅ + 既存セッション ✅ | 同上 (`-A` により attach される) | **スキップ**し受付可能を即セット |
| **C. tmux 未インストール** | tmux 検出 ❌ | `cd '<dir>' && exec zsh -l` | 実行する |

### tmux セッション名

形式は `aidea-claude-<companionIndex>-<slug>-<hash>`。Terminal の `aidea-<slug>-<hash>-<instance>` と prefix で分離するため衝突しない。

- `<companionIndex>`: 紐付く Companion の index (0…8)。Companion ごとに別 tmux セッションを持つ
- `<slug>`: プロジェクトルートのディレクトリ名を小文字英数・ハイフン区切りに正規化
- `<hash>`: フルパスから生成した短いハッシュ (同名ディレクトリ区別用)

### 経路 A: 新規起動

```
1. tmux new-session で tmux セッションを新規作成 (zsh が起動)
2. +1.0s: "claude\n" を送って Claude CLI を起動
3. +5.0s: 起動時指示コマンドを送信 (v8 以降の固定パターン、ADR 0022)
4. +5.3s: "\r" を送って submit させる
5. +6.0s: 受付可能。保留されていた Frontchannel 送信を順に flush
```

- ステップ 3-4 は分離して送る。Claude Code (Ink 製 TUI) は bracketed paste を有効にしており、本文と `\r` を一度に送ると `\r` も paste の一部とみなされ submit されないため、本文の入力処理が終わる間 (≈0.3s) を挟んでから `\r` を送る
- 起動時指示コマンドが空の場合はステップ 3-4 をスキップし、受付可能は `+1.3s` でセット
- v8 以降のデフォルトは `".aidea/claude/companions/<index>/instructions.md を読んで従ってね"` の固定パターン。Claude が Read ツールで本体を読みに行き、必要に応じて `aidea.md` / `speech.md` 等を段階的開示する
- ADR 0008 により、非対話シェルから直接 `claude` を exec せず、**対話シェル内でキー送信**する
- ハンドオフ / レコメンドプロンプトのように起動直後に Frontchannel へ送信したい場合は、固定遅延で待たず**受付可能まで保留する送信**を使う。受付可能になる前は内部に積まれ、`+6.0s` で flush される
- Frontchannel の送信も**本文と `\r` を分離して送る** (本文送信 → ≈0.3s 後に `\r`)。理由はステップ 3-4 と同じ (bracketed paste で `\r` がペーストの一部とみなされ submit されない)。自動起動直後の flush や、ハンドオフ / inbox / スケジューラからの送信でも submit が確実に効くようにするため

### 経路 B: 再 attach (自動起動シーケンスをスキップ)

tmux セッションが既存の場合、内部で `claude` TUI が既に起動 (Aidea 終了時に PTY だけ閉じられた状態) しているはず。ここで `claude\n` を再送すると **TUI の入力欄に "claude" という文字列が入力されてしまう** ため、自動起動シーケンスをまるごとスキップする。

```
1. tmux new-session -A で既存セッションに attach (zsh プロンプトではなく claude TUI が表示される)
2. 受付可能を即座にセット (Frontchannel からの送信を受け付け可能)
```

- 起動時指示コマンドは **再送しない**。再 attach 時の Claude TUI には既に同じ Companion の起動時指示が読み込まれている前提
- ハンドオフ受信などで保留付き送信を経由する場合も、受付可能なので即時送信される
- 判定は tmux 起動コマンド組み立て時点で `tmux has-session -t <name>` を実行し、exit code で判定する

### 経路 C: tmux なし (フォールバック)

tmux が探索パス (`/opt/homebrew/bin/tmux` → `/usr/local/bin/tmux` → `/usr/bin/tmux`) のいずれにも見つからない場合は従来通り `cd <dir> && exec zsh -l` で直接起動し、経路 A と同じ自動起動シーケンスを実行する。Aidea 終了で claude プロセスは消滅する (永続化なし)。



Companion 管理が Companion → Session の対応表を保持し、本 Session と 1:1 対応する。
詳細は [../companions/companion.md](../companions/companion.md) を参照。

## Scene とレコメンドプロンプト

セッション共通の仕組み ([../frontchannels/scene.md](../frontchannels/scene.md)) で、Cmd+Enter でのレコメンド送信に対応する。

| Companion index | Scene 識別子 |
|---|---|
| `0` | `"claude:0"` |
| `1` | `"claude:1"` |
| … | … |
| `8` | `"claude:8"` |
| なし | なし (レコメンド無反応) |

- Scene キーは Companion ごとに分かれるため、**Companion 毎に別レコメンドプロンプトを持てる** (例: テスト担当 Companion 2 なら `"テストして"`、レビュー担当 Companion 4 なら `"差分をレビューして"`)。
- 既定の Companion の初期値は自 Companion の index に一致させる (例: `claude:5` なら `5`)。これにより Cmd+Enter 起動時にそのセッション自身の Companion が最初に選択される (詳細は [../companions/recommend-mode.md](../companions/recommend-mode.md))。
- 初期プロンプトは空。ユーザは Claude ツール下部のプロンプト編集エリアで Companion 固有のプロンプトを追加できる。
