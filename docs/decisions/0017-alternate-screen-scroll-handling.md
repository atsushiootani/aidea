---
title: "0017: Alternate Screen 使用中のスクロールを入力変換で対処する"
description: Claude CLI のトランスクリプトモード時にホイールスクロールを Ctrl+U/D に、ホイールクリックを Ctrl+O に NSEvent モニターで変換する判断
status: 採用
derived_from:
  - docs/decisions/0008-no-claude-autostart.md
  - docs/decisions/0016-terminal-mouse-event-suppression.md
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-08
---

# 0017: Alternate Screen 使用中のスクロールを入力変換で対処する

**日付**: 2026-04-17

## 背景

ターミナル上で Claude CLI (`claude` コマンド) を実行すると、ホイールスクロールが効かなくなる。
通常のシェルでは問題なく動作する。

### ターミナルの Alternate Screen Buffer

端末エミュレータには 2 つのスクリーンバッファが存在する:

| バッファ | 用途 | スクロール履歴 |
|---------|------|--------------|
| **Normal Buffer** | 通常のシェル操作 | あり（scrollback） |
| **Alternate Buffer** | TUI アプリ (vim, less, claude CLI 等) | なし |

TUI アプリは起動時に Alternate Screen に切り替え (`ESC[?1049h`)、終了時に Normal Screen に戻す (`ESC[?1049l`)。
Alternate Screen にはスクロールバッファがないため、SwiftTerm の `scrollUp()`/`scrollDown()` が実質無効になる。

### Claude CLI のモード

Claude CLI には 2 つの表示モードがあり、`Ctrl+O` でトグルする:

| モード | 説明 | 最下行の特徴 |
|--------|------|-------------|
| **通常モード** | チャット形式の入力画面 | プロンプト入力欄 |
| **トランスクリプトモード** | 詳細な会話履歴の閲覧 | `Showing detailed transcript · ctrl+o to toggle · ↑↓ scroll ...` |

**注意**: 通常モードで `Ctrl+D` を 2 回押すと Claude CLI が終了する（EOF 送信）。
トランスクリプトモードでのみ `Ctrl+U` / `Ctrl+D` を送信する判定が重要な理由の一つ。

トランスクリプトモードでは以下のキー操作が有効:
- `↑` / `↓` : 1 行スクロール
- `Ctrl+U` / `Ctrl+D` : 半ページスクロール
- `PageUp` / `PageDown` : 1 ページスクロール
- `[` : 出力を印刷
- `v` : コードエディタで開く

## 判断

**Alternate Screen 使用中かつトランスクリプトモード時に、ホイールスクロールを `Ctrl+U` / `Ctrl+D` (半ページスクロール) に変換して PTY に送信する。**

加えて、**ホイールクリック (ミドルクリック) を `Ctrl+O` に変換**してモード切替を容易にする。

### トランスクリプトモードの判定

`terminal.getLine(row: terminal.rows - 1)` で最下行のテキストを取得し、
`"transcript"` を含むかどうかでリアルタイム判定する。
トグル状態の内部追跡ではなくバッファの実テキストを読むため、
キーボードから直接 `Ctrl+O` を押した場合にも正しく追従する。

```swift
private var isTranscriptMode: Bool {
    guard terminal.isCurrentBufferAlternate else { return false }
    let lastRow = terminal.rows - 1
    guard let line = terminal.getLine(row: lastRow) else { return false }
    let text = line.translateToString(trimRight: true)
    return text.contains("transcript")
}
```

### 実装: PersistentTerminalView

```
NSEvent ローカルモニター (.scrollWheel)
  ↓
alternate screen? → NO → SwiftTerm の通常スクロール
  ↓ YES
isTranscriptMode? → NO → イベントをスルー
  ↓ YES
deltaY > 0 → Ctrl+U (0x15) を PTY に送信
deltaY < 0 → Ctrl+D (0x04) を PTY に送信

NSEvent ローカルモニター (.otherMouseDown, buttonNumber == 2)
  ↓
Ctrl+O (0x0f) を PTY に送信
```

## 理由

1. SwiftTerm の `scrollWheel` は `public` だが `open` ではなく、override 不可
2. Alternate Screen にスクロールバッファがないのは端末エミュレータの仕様であり、SwiftTerm のバグではない
3. NSEvent ローカルモニターで `scrollWheel` を横取りし、キー入力に変換する方式は iTerm2 等でも採用されている手法
4. 最下行テキストによる判定は、Claude CLI のバージョンに依存するがシンプルで確実

## トレードオフ

- Claude CLI が最下行のテキストフォーマットを変更すると判定が壊れる
  → その場合はテキストパターンを更新するだけで対応可能
- `Ctrl+U` / `Ctrl+D` は Claude CLI のトランスクリプトモード固有のキーバインド
  → 他の TUI アプリには効かない可能性がある（vim の `Ctrl+U`/`Ctrl+D` には効く）
- ホイールクリックを `Ctrl+O` に固定している
  → 将来 Claude CLI のキーバインドが変わった場合は変更が必要

## 追記: マウスイベント転送への一般化 (issue #260)

上記の Ctrl+U/D 方式は Claude CLI 固有だった。**Terminal ツールで一般の TUI (`less` / `vim` / `man` /
`htop` 等) を実行中**も同じ「ホイールが効かない」問題が起きる。当初は「ホイール → 矢印キー変換」で
対処しようとしたが、**根本原因を調べ直して方式を変更した**。

### 根本原因

Aidea は Terminal / Claude を **tmux 経由**で起動する。ここで 2 つの事実が重なる:

1. **SwiftTerm の `scrollWheel` はホイールをマウスイベントとして PTY へ転送しない** — 自前の
   `scrollUp()` / `scrollDown()` (外側スクロールバック) を動かすだけ。
2. **tmux は常時 alternate screen + `mouse on`** で動く。外側スクロールバックは空で無意味、かつ
   tmux はホイールをマウスイベントとして待っているのに、SwiftTerm がそれを送らないので何も起きない。

さらに、tmux の alternate screen は**セッション全体で常時 true** のため、外側 (SwiftTerm) からは
「プロンプトにいるのか TUI を実行中か」を `isCurrentBufferAlternate` で判別できない。当初の矢印キー変換は
この判別に依存していたため、プロンプトでもホイールが矢印キーになり**コマンド履歴が表示される**バグを生んだ。

### 判断 (改訂)

**マウストラッキング中 (`terminal.mouseMode != .off`) は、ホイールを SGR マウスホイールイベントとして
PTY に転送する** (`terminal.encodeButton(button: 4/5, ...)` + `terminal.sendEvent(buttonFlags:x:y:)`)。
tmux (やマウス対応 TUI) がスクロールを解釈する。tmux は自身が管理する内側の alternate screen 状態を
知っているため、「プロンプト = コピーモード / alt-screen アプリ = 矢印・マウス転送」を正しく振り分ける。
これは Terminal と Claude で共通の 1 つの `scrollMonitor` に集約する。

- ホイールボタン: X11 マウスプロトコルの up=4 / down=5 (encodeButton が 64/65 に変換)
- 送信量: マウスホイール 1 ノッチ 1 回、トラックパッド `scrollingDeltaY` を 16 pt ごと 1 回 (上限あり)。1 回のスクロール行数は tmux が決める
- **フォールバック** (`mouseMode == off`、tmux 未使用等): Claude は従来どおり transcript 時 Ctrl+U/D、Terminal は SwiftTerm 標準スクロールバック。ホイールクリック → Ctrl+O は Claude 専用のまま維持

### トレードオフ (改訂分)

- tmux の `mouse on` に依存する。`mouse off` の場合は Terminal のスクロールは効かない (フォールバックの範囲)
- マウス位置は概算 (`cellPosition`)。Aidea は 1 セッション 1 tmux ペインなので pane 選択に支障はない
- 転送量は体感値。速すぎ/遅すぎる場合は tick 換算の閾値を調整する

## 関連

- Issue #52 / Issue #260
- [ADR 0016: ターミナルの mouseMoved を NSEvent モニターで抑制する](./0016-terminal-mouse-event-suppression.md) — 同じ NSEvent モニター手法
- [ADR 0008: ターミナルで claude を自動起動しない](./0008-no-claude-autostart.md) — Claude CLI の制約に関する判断
