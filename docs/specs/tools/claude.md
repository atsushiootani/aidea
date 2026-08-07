---
title: Tool 仕様: Claude
description: Claude Code を自動起動し Backchannel で Aidea と連携するターミナル Tool の仕様
derived_from:
  - docs/decisions/0008-no-claude-autostart.md
  - docs/decisions/0017-alternate-screen-scroll-handling.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/window/
  - docs/specs/backchannels/backchannel.md
syncs_with:
  - docs/specs/sessions/claude.md
  - docs/specs/aspects/keybindings.md
  - docs/specs/companions/companion.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-10
---

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
| アイコン | ターミナルのアイコン | 吹き出しのアイコン |
| 表示名 | Terminal | Claude |

Claude セッションは Terminal と同じ端末 View を共用し、その上に自動起動・Backchannel 指示送信・
実行中/読み上げ中の状態公開 (issue #45) を上乗せしたもの。

---

## 起動フロー

tmux の有無と既存セッションの有無で 3 経路に分岐する。詳細な状態遷移は [sessions/claude.md#自動起動シーケンス](../sessions/claude.md#自動起動シーケンス) を参照。

| 経路 | 条件 | PTY 内側で起動するもの | 自動起動シーケンス |
|------|------|-----------------------|---------------|
| **A. tmux 新規** | tmux 検出 + 既存セッションなし | tmux 経由の zsh | 実行 |
| **B. tmux 再 attach** | tmux 検出 + 既存セッションあり | 既存 tmux セッション (claude TUI が継続中) | **スキップ** (再送禁止) |
| **C. tmux 未インストール** | tmux 検出なし | 直接 `zsh -l` | 実行 |

経路 A / C の自動送信タイミング:

```
1. PTY で zsh 起動 (経路 A は tmux 経由、経路 C は直接)
2. +1.0s: "claude\n" を送って claude を起動
3. +5.0s: Companion 指示書読み込みコマンドを送信
4. +5.3s: "\r" を送って submit
5. +6.0s: 受付可能 (isReady) にマーク (Frontchannel からの送信が安全に使える状態)
```

### 自動送信のタイミング

| ステップ | 遅延 | 内容 |
|---------|------|------|
| zsh 起動 | 0s | PTY プロセス開始 (tmux 経由 or 直接) |
| claude 送信 | +1.0s | `claude\n` を PTY に送信 |
| 指示書読み込みコマンド送信 | +5.0s | 固定パターン文字列 `.aidea/claude/companions/<index>/instructions.md を読んで従ってね` を PTY に送信 |
| Enter 送信 | +5.3s | `\r` を送って submit させる |
| 受付可能 (isReady) | +6.0s | Frontchannel からの送信を受け付け可能とマーク。待機中の送信はこのタイミングで実行される |

- PTY へのキー送信は対話シェル内での手入力と同等 (ADR 0008 の非対話シェル問題を回避)
- 指示書読み込みコマンドが空の場合はステップ 3-4 をスキップし、受付可能は `+1.3s` でセット
- 本文と `\r` を分離するのは、Claude Code (Ink 製 TUI) が bracketed paste を有効にしており、両者を一度に送ると `\r` も paste の一部とみなされ submit されないため。本文の入力処理が終わる間 (≈0.3s) を挟む
- v8 以降、Aidea が送るのは固定パターン文字列のみ。Claude が Read ツールで `instructions.md` 本文を取りに行く (ADR 0022)。Claude 側は `instructions.md` 冒頭から `.aidea/claude/aidea.md` / `speech.md` / `handoff.md` 等を段階的に読み込む
- 経路 B (再 attach) では自動起動シーケンスを **完全にスキップ** し、受付可能だけを即セットする。既に起動中の Claude TUI に `claude\n` を再送すると入力欄に "claude" 文字列が入力されてしまうため

### tmux による永続化

Claude セッションも Terminal と同様に tmux で PTY を永続化する (Terminal の仕様は [sessions/terminal.md#永続化](../sessions/terminal.md#永続化) を参照)。

- セッション名: `aidea-claude-<companionIndex>-<slug>-<hash>` (Terminal の `aidea-<slug>-<hash>-<instance>` と prefix で分離)
- Aidea 終了時: PTY (tmux クライアント) が閉じるが、tmux サーバと claude プロセスは継続
- 再起動後の再 attach: 同名 tmux セッションに自動 attach し、自動起動シーケンスをスキップする
- tmux 未インストール時: 経路 C にフォールバック (永続化なし)

---

## Backchannel 連携

コンパニオンの `instructions.md` 内で `.aidea/claude/` 配下の機能ファイルを参照することで Backchannel 機能が有効化される (機能宣言チェーン、ADR 0022)。Aidea が起動時に送るのは指示書読み込みの固定パターン文字列のみで、本文は Claude が Read ツール経由でファイルから取得する。

1. 初回セットアップ処理が `.aidea/claude/aidea.md` / `speech.md` / `handoff.md` と `companions/<0..8>/instructions.md` を配置済み (既存ファイルは上書きしない)
2. 指示書読み込みコマンド送信により Claude が `instructions.md` を読み込む
3. `instructions.md` の参照行に従って Claude が `aidea.md` / `speech.md` / `handoff.md` 等を段階的に読み込む (参照しない Companion はその機能を持たない)
4. 以降 Claude が `.aidea/backchannels/<companion-index>/speech-{timestamp}.txt` や `handoff-{timestamp}.json` にメッセージを書き出す (ADR 0024)
5. Aidea の監視処理が検知して VOICEVOX 読み上げ / 他 Companion への配送を行う

詳細は [backchannels/voicevox.md](../backchannels/voicevox.md) / [backchannels/handoff.md](../backchannels/handoff.md) を参照。

---

## 実行中判定 `isBusy` (issue #45)

Claude セッションは**実行中かどうか**を外部に公開する。Companion アイコンの表情切替 ([../companions/companion.md#表情状態表示-issue-45](../companions/companion.md#表情状態表示-issue-45)) が参照する。

### 判定ロジック

- **実行中にする**: PTY にキー送信したタイミング。Frontchannel の送信や自動起動が PTY に書き込んだ直後に明示的にセットする (出力を待たずに UI を考え中表示に切り替えるため)
- **初期タイマー (3.0s)**: 実行中セットと同時に 3.0s のタイマーを張る。Claude API のレイテンシで最初の出力が来るまでの間も実行中を維持するための猶予期間
- **タイマー延長 (0.5s)**: 実行中に PTY 出力が来たらタイマーを 0.5s に張り直す (応答ストリーミング中は延長され続けて実行中を維持)
- **解除する**: 実行中に PTY 出力が **0.5 秒** 途切れたら実行中を解除する。送信から 3.0s 以内に出力が来なかった場合も同様

> **Never**: PTY 出力を観測しただけで実行中にはしない。Claude CLI はアイドル時もカーソル点滅 / 定期再描画で出力を出すため、「出力観測 = 実行中」にすると常時実行中になる。送信ベースで実行中にすることで「ユーザ/Aidea が Claude に仕事を投げた期間」のみを実行中と判定する。

- 出力静止判定の 0.5s は `claude` CLI が tool 実行中やテキストストリーミング中に細かく出力することを考慮した体感値
- 初期猶予の 3.0s は Claude API のレイテンシ (通常 1〜3s 程度) をカバーする体感値

### ライフサイクル

| タイミング | 実行中 | 遷移理由 |
|---|---|---|
| Claude セッション初期化直後 | 解除 | 送信未実施 |
| 自動起動シーケンス (claude / 指示書 / Enter 送信) | 各送信直後に 実行中 | 3.0s タイマー開始 |
| TUI 初期描画中〜受付可能まで | 実行中 維持 | 応答出力で 0.5s タイマーに切り替え延長 |
| 入力待ちプロンプト表示 (起動後の初回アイドル) | 0.5s 静止後 解除 | タイマー満了 |
| ユーザが `Cmd+Enter` でプロンプト送信 | 送信直後 実行中 | 3.0s タイマー開始 |
| Claude の応答ストリーミング中 | 実行中 維持 | 応答出力で 0.5s タイマーに切り替え延長 |
| 応答完了 → 入力待ちプロンプト表示 | 0.5s 静止後 解除 | タイマー満了 |
| PTY 終了時 | 解除 | (アイドル扱い) |

### 外部参照

Companion アイコンが「実行中」状態のとき、考え中の表情＋記号に切り替える。

**Never**: 実行中判定をターミナル出力の文字列パース (「> 」「✻」など特定トークン検知) で行わない。出力静止ベースの単純判定に留める ([ADR 0008](../../decisions/0008-no-claude-autostart.md) の思想踏襲)。

---

## 読み上げ中判定 `isSpeaking` (issue #45)

Claude セッションは**読み上げ中かどうか**を外部に公開する。状態実体は持たず、音声キューが当該 Companion を読み上げ中かどうかを返す薄いファサード。Companion アイコンの表情切替 ([../companions/companion.md#表情状態表示-issue-45](../companions/companion.md#表情状態表示-issue-45)) が実行中と対称に参照できるよう揃える位置づけ。

### 状態源

- **SSoT**: 音声キューが公開する「現在読み上げ中の companionIndex」([../backchannels/voicevox.md](../backchannels/voicevox.md))
- **注入**: Claude セッション生成 / 復元時に音声キューへの参照を持たせる
- **伝播**: 音声キューの状態変化が読み上げ中判定を読むスコープに自動伝播する (Claude セッション側に別途状態を持たせない)

### 外部参照

Companion アイコンが「読み上げ中」状態のとき、笑顔の表情＋記号に切り替える。

---

## キーボードショートカット

### グローバル

| キー | アクション |
|------|-----------|
| `Cmd+Option+8` | Claude ツールにフォーカス（複数あれば循環） |

### ターミナル内操作（Aidea が変換）

| キー/操作 | 条件 | 送信されるキー | アクション |
|----------|------|-------------|-----------|
| ホイールスクロール上 | トランスクリプトモード時 | `Ctrl+U` | 半ページ上スクロール |
| ホイールスクロール下 | トランスクリプトモード時 | `Ctrl+D` | 半ページ下スクロール |
| ホイールクリック | 常時 | `Ctrl+O` | 通常モード ↔ トランスクリプトモードのトグル |

トランスクリプトモードの判定は、ターミナルバッファの最下行に `"transcript"` を含むかどうかで行う。
詳細は [ADR 0017](../../decisions/0017-alternate-screen-scroll-handling.md) を参照。

ホイールスクロールは Claude と Terminal で共通に扱う。tmux mouse on 等でマウストラッキング中は
ホイールを **SGR マウスイベントとして転送**し tmux に処理を委ねる
([tools/terminal.md#ホイールスクロール-issue-260](./terminal.md#ホイールスクロール-issue-260))。
上表の Ctrl+U/D はマウストラッキングが無い (tmux 未使用等) ときのフォールバック。

---

## タブ右クリックメニュー

Claude タブを右クリックすると、コンテキストメニューを表示する。対象は Claude タブのみで、
Terminal など他のタブには従来どおりメニューを出さない (Preview タブは [preview.md#タブ右クリックメニュー-issue-238](./preview.md#タブ右クリックメニュー-issue-238) の既存メニュー)。
共通の右クリック規約は [sessions/ui-rules.md#右クリックコンテキストメニュー](../sessions/ui-rules.md#右クリックコンテキストメニュー) に従う。

| 項目 | 動作 |
|---|---|
| instruction読み込み | `@.aidea/claude/companions/<companionIndex>/instructions.md` を Frontchannel でセッションに送信する |
| (区切り線) | |
| タブを閉じる | このタブを閉じる (× ボタンと同じ) |

- 「instruction読み込み」は Claude Code の `@` ファイル参照記法で Companion 指示書を再読み込みさせるためのもの。
  `/clear` 後などに指示書を読み直させるユースケースを想定
- 送信文字列は `@` + Companion 指示書 (instructions.md) の相対パス (起動時の読み込みコマンドと同じパスパターン)。
  companionIndex はタブに紐付く Companion から解決する
- companionIndex が解決できない場合 (Companion 未バインドの Claude タブ) は「instruction読み込み」を無効化 (disabled) する
- セッションが受付可能になる前なら、送信は保留され起動シーケンス完了後に送られる

---

## 境界

### Always
- 対話シェル内でキー送信により claude を起動する（非対話シェルからの exec ではない）
- Backchannel 指示はコンパニオンの `instructions.md` 経由で `.aidea/claude/*.md` を読むよう Claude に伝える形で行う (v8 以降、ADR 0022)
- 端末 View は Terminal ツールと共用する
- tmux 検出時はセッション名 prefix `aidea-claude-` で Terminal と分離する
- 再 attach 経路 (tmux has-session が成功する経路) では自動起動シーケンスを実行しない

### Never
- 非対話シェルから直接 claude を exec しない（ADR 0008）
- claude の起動完了を出力パースで検知しない（固定遅延で対応）
- 既存 tmux セッションに対して `claude\n` や指示書読み込みコマンドを再送しない (TUI 入力欄に文字列が漏れるため)
