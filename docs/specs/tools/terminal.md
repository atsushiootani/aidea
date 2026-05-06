---
title: Tool 仕様: Terminal
description: SwiftTerm ベースの PTY ターミナル Tool 仕様。tmux が利用可能な場合はプロセス永続化、claude 自動起動はしない純粋なシェル環境
derived_from:
  - docs/decisions/0006-only-swiftterm-dependency.md
  - docs/decisions/0008-no-claude-autostart.md
  - docs/specs/sessions/ui-rules.md
  - docs/specs/window/
syncs_with:
  - docs/specs/sessions/terminal.md
  - docs/specs/aspects/keybindings.md
  - docs/specs/tools/preview.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-05-06
---

# Tool 仕様: Terminal

ターミナル (PTY) を提供する Tool。純粋なシェル環境のみを起動する。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/terminal.md](../sessions/terminal.md) を参照。
共通 UI 規約は [sessions/ui-rules.md](../sessions/ui-rules.md) と [window/](../window/README.md) を参照。

---

## 概要

- SwiftTerm (`LocalProcessTerminalView`) ベースの PTY ターミナル
- **複数インスタンス可** — Window 内で複数の Terminal セッションを開ける
- `WorkspaceState.projectRoot` を初期ディレクトリとして起動
- tmux が利用可能な場合は `exec tmux new-session -A -s <name>` で起動し、Aidea を閉じてもシェルプロセスが継続する ([sessions/terminal.md#永続化](../sessions/terminal.md#永続化) 参照)
- tmux が利用不可の場合は対話シェル (`exec zsh -l`) で起動（ADR 0008 参照）
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

## クリック起動

ターミナル上のテキストを **単純クリック (mouseDown→ドラッグなしで mouseUp)** すると、種別に応じて action を発火する。`PersistentTerminalView` が提供する機能なので、Claude Tool でも同じ挙動になる。ドラッグでの範囲選択は維持される。

| 種別 | 検出 | アクション |
|---|---|---|
| URL | SwiftTerm 標準の URL/OSC 8 ハイパーリンク検出 | `NSWorkspace.shared.open(url)` でブラウザ起動 |
| ファイルパス | Aidea 独自の regex 検出 + 実在確認 (issue #71) | `SessionRegistry.openPreviewAsSibling(for:title:)` でターミナルと同じペインの右隣に Preview タブを開く |

クリックターゲット (URL またはファイルパス) 上にマウスがホバーしたとき、カーソルを `NSCursor.pointingHand` (指マーク) に変えてクリック可能であることを示す。ターゲットから外れたら通常 (`NSCursor.iBeam`) に戻す。

mouseMoved による URL 自動オープン (ホバーだけでブラウザが開く SwiftTerm 標準挙動) は NSEvent モニターで握りつぶす ([issue #54](https://github.com/atsushiootani/aidea/issues/54) 対策、既存)。クリック起動はあくまで mouseUp でのみ発火する。

### クリック判定 (tap vs drag)

mouseDown と mouseUp の位置が **threshold (4 pt) 以下** に収まり、かつその間に有意な mouseDragged が発生していない場合のみ「クリック」と判定する。それ以外はドラッグ選択として扱い、クリック起動は発火しない。Cmd 修飾キーは **不要** (押されていても押されていなくても同じ挙動)。

### URL クリック

- SwiftTerm の `TerminalViewDelegate.requestOpenLink` を `TerminalLinkGuard` でプロキシし、上記「クリック判定」を満たすときに起動する
- 起動先は `NSWorkspace.shared.open(url)` (システム標準のブラウザ)
- OSC 8 ハイパーリンク (`\e]8;;<url>\e\\<text>\e]8;;\e\\`) と、SwiftTerm 標準の URL detector の両方に対応

### ファイルパスのクリック起動 (issue #71)

ターミナル出力中のファイルパスを単純クリックで Preview に開く。「URL クリックと同じ体感」が目標。

#### 検出 regex

`<path>` または `<path>:<line>` 形式を以下の条件で検出する:

- 文字種: ASCII 英数 + `.` / `_` / `-` / `/` (絶対パスの先頭 `/` も許可)
- 拡張子: 末尾が `.<2 文字以上の英数>` で終わる (`.swift` / `.md` / `.ts` / `.json` 等)
- 区切り: 半角空白 / タブ / 行頭 / 行末 / 引用符 (`"` / `'` / `` ` ``) / カッコ (`(` / `)` / `[` / `]` / `<` / `>`)
- 行番号 (オプション): パス末尾に `:<整数>` が続けば行番号として保持 (将来用、MVP では使用しない)

検出する例:
- `Sources/Foo.swift`
- `/Users/alice/proj/main.go`
- `docs/specs/tools/terminal.md:42`
- `./build/output.json`

検出しない例:
- 拡張子規則に当てはまらない素のドメイン名・IP アドレス (`192.168.1.1` など)
- 拡張子なしのファイル名 (`Makefile` 等。MVP では対象外)

#### パス解決

1. 検出した `path` が絶対パス (`/` 始まり) なら **そのまま**
2. 相対パスなら `WorkspaceState.projectRoot` を起点に絶対化する
3. 解決後の URL が `FileManager.fileExists` でファイルとして実在しなければ **無音で無視** (URL クリックの失敗時挙動と同じ)

PTY の `cwd` は **追跡しない** (MVP)。`cd` 後に表示された相対パスは projectRoot 起点に解決されるため不正確になり得るが、Claude や `grep -rn` 等の主要出力源は projectRoot 起点が大半なので許容する。`hostCurrentDirectoryUpdate` を実装した cwd 追跡は別 issue で扱う (将来拡張)。

#### Preview 起動

検出 + 実在確認後、以下を呼ぶ:

```swift
SessionRegistry.openPreviewAsSibling(for: absoluteURL, title: relativePath)
```

- `title` は projectRoot からの相対パス (絶対パスは長くタブで読みにくいため)
- **同じペインの右隣に新規 Preview タブを挿入する** (`openPreviewAsSibling`)。ターミナルで作業中に他ペインへフォーカスを奪われない方が体感が自然なため。Filer / Kit のダブルクリックが使う `openPreview` (別ペイン配置) とはここが異なる
- 既存の Preview dedupe 規約 ([sessions/active-session.md#preview-を開くときの呼び出し規約](../sessions/active-session.md#preview-を開くときの呼び出し規約)) に従い、同じ URL の Preview がすでに存在すれば新規作成せずアクティブ化する

#### `:行数` 指定の行ジャンプ (将来拡張)

issue #71 の `(want)` 項目。Preview 側のコード/テキストビューが現状行ジャンプ機構を持たない (Markdown のみ `scrollTo("line-\(N)")` 対応) ため、**MVP では行番号を検出はするが Preview への引き渡しは行わない** (= ファイルを開くだけ)。Preview 側に行ジャンプ API が追加された段階で `SessionRegistry.openPreview(for:title:line:)` 等の拡張を検討する (別 issue)。

### ホバー時カーソル変化

クリックターゲット (URL / ファイルパス) 上にマウスがホバーしたら指マークに切り替える。

- mouseMoved を `addLocalMonitorForEvents` で観測し、座標→セル変換でホバー位置の文字を取得する
- そのセルが SwiftTerm 標準の URL 検出範囲内、または `TerminalPathResolver` がパスとして検出した範囲内なら `NSCursor.pointingHand.set()` を呼ぶ
- ターゲット外に出たら `NSCursor.iBeam.set()` (ターミナル既定) に戻す
- 実在しないファイルパス候補 (regex は通るが `fileExists` が false) もカーソルは変えない (クリックしても何も起きないため)
- SwiftTerm 内部の mouseMoved 経由 URL 自動オープンは引き続き抑制 (issue #54 対策、既存挙動を維持)

### 実装コンポーネント

| コンポーネント | 役割 |
|---|---|
| `PersistentTerminalView` (拡張) | mouseDown/mouseUp/mouseMoved を捕捉し、(1) クリック判定 (tap vs drag)、(2) ホバーカーソル変化、(3) パス検出時の Preview 起動を行う |
| `TerminalLinkGuard` (拡張) | `requestOpenLink` プロキシ。クリック判定 OK のときに URL を `NSWorkspace.shared.open` (Cmd 修飾チェックは外す) |
| `TerminalPathResolver` (新規) | regex 定義・projectRoot 起点の絶対化・実在確認を担う純関数ヘルパ。`Foundation` のみで完結し、SwiftTerm/UI 依存を持たない (テスト容易性) |

---

## 境界

### Always
- tmux が利用可能なら `exec tmux new-session -A -s <name>` で PTY プロセスを tmux セッション内に起動する
- tmux が利用不可なら対話シェル (`exec zsh -l`) にフォールバックする
- PTY は初回生成後にキャッシュし、タブ切替・ペイン移動で再生成しない
- クリック起動は Terminal Tool / Claude Tool の両方で同じ挙動 (PersistentTerminalView 共用)
- クリック起動は mouseDown→mouseUp の距離が threshold (4 pt) 以下かつドラッグなしのときのみ発火
- URL とファイルパスの両方が **単純クリック** で開く (Cmd 修飾は不要・押されていても同じ挙動)
- クリックターゲット (URL / 実在するファイルパス) 上では `NSCursor.pointingHand` でクリック可能であることを示す
- ファイルパスのクリック起動は `WorkspaceState.projectRoot` を相対パスの起点とする
- 検出パスがファイルとして実在しない場合は無音で無視 (URL クリックの失敗時挙動に揃える)
- ファイルパスから開く Preview は **ターミナルと同じペインの右隣** に新規タブで挿入する (`openPreviewAsSibling`)

### Never
- Terminal ツールから `claude` を自動起動しない（Claude ツールの責務）
- 非対話シェルから直接プロセスを exec しない（ADR 0008）
- ドラッグ選択中の mouseUp でクリック起動を発火しない (テキスト選択を優先)
- SwiftTerm 標準の mouseMoved 経由 URL 自動オープンを許可しない (mouseUp 必須)
- PTY の `cwd` 追跡で相対パスを解決しない (MVP では projectRoot 固定)
- `:行数` を Preview に引き渡さない (MVP)
- `TerminalLinkGuard.requestOpenLink` で scheme を持たない link 文字列を `NSWorkspace.shared.open` に渡さない (SwiftTerm の link detector がファイルパスを link として渡してきても、Preview 起動は `handlePathClickIfNeeded` が担うため。`open` に渡すと Finder が `-50` ダイアログを出してしまう)
