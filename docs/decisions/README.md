# Architecture Decision Records

Aidea の設計判断を 1 件ずつ記録する。フォーマットは [Michael Nygard 形式](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) を踏襲。

## 一覧

| # | タイトル | 状態 |
|---|---|---|
| [0001](./0001-swift-swiftui.md) | Electron ではなく Swift/SwiftUI を採用 | 採用 |
| [0002](./0002-no-code-editor.md) | コードエディタ機能を持たない | 採用 |
| [0003](./0003-claude-api-direct.md) | Claude API を直接叩く（Claude Code CLI は別途使う） | 採用 |
| [0004](./0004-git-diff-with-diff2html.md) | Git diff は WebView + diff2html で表示 | 暫定 |
| [0005](./0005-obsidian-hybrid.md) | Obsidian 連携は URL スキーム + 直接ファイル操作のハイブリッド | 採用 |
| [0006](./0006-only-swiftterm-dependency.md) | 外部依存は SwiftTerm のみに絞る | 採用 |
| [0007](./0007-name-aidea.md) | プロジェクト名は Aidea | 確定 |
| [0008](./0008-no-claude-autostart.md) | ターミナルでは claude を自動起動しない | 採用 |
| [0009](./0009-nsoutlineview-and-fsevents.md) | ファイラは NSOutlineView + FSEvents で実装する | 採用 |
| [0010](./0010-drawio-rendering-paths.md) | drawio ファイルの描画は形式ごとに異なる経路を使う | 採用 |
| [0011](./0011-cmd-w-via-nsevent-monitor.md) | Cmd+W のタブクローズは NSEvent local monitor で実装する | 採用 |
| [0012](./0012-keyboard-focus-dual-path.md) | キーボードフォーカスは AppKit と SwiftUI の 2 経路で管理する | 採用 |
| [0013](./0013-session-as-first-class-object.md) | Session を first-class object にして Window レベルで管理する | 提案 |
| [0014](./0014-no-ctrl-number-shortcuts.md) | Ctrl+数字キーのショートカットを使わない | 採用 |
| [0015](./0015-wkwebview-scope-and-chrome-coexistence.md) | WKWebView の制約を許容し Chrome 併用を前提とする | 採用 |
| [0016](./0016-terminal-mouse-event-suppression.md) | ターミナルの mouseMoved を NSEvent モニターで抑制する | 採用 |
| [0017](./0017-alternate-screen-scroll-handling.md) | Alternate Screen 使用中のスクロールを入力変換で対処する | 採用 |

## 状態の値

`提案` / `採用` / `暫定` / `確定` / `廃止` / `置換 (→ NNNN)`

## 新規追加

ファイル命名 (`NNNN-kebab-title.md`)・インデックス更新の義務は [../LAYOUT.md](../LAYOUT.md) を参照。

---

## ヘルスチェック (PR 時に実施)

ADR が増えるにつれて矛盾や参照漏れが溜まりやすい。PR レビューのタイミングで以下を走らせる。Claude Code で `/aidea.docs-healthcheck` コマンド (specs / decisions 両方まとめて実行) または「decisions のヘルスチェックして」と自然言語で実行可能。

### チェック項目

1. **矛盾 (Contradiction)**
   - 2 つ以上の ADR が同じトピックについて**異なる方針**を主張していないか
   - 古い判断を新しい ADR がひっくり返しているが、古い ADR に「廃止」「置換 (→ NNNN)」「進化予定」の記載がないケースも矛盾扱い

2. **未定義参照 (Undefined reference)**
   - ADR 本文で言及している**概念・仕様・ファイル・ルールが、リポジトリ内のどこにも定義されていない**ものをフラグ
   - 例: 「Scene 概念を使う」と書いてあるのに `docs/specs/frontchannels/scene.md` 等に定義がない
   - 例: 削除済みファイル (`boundaries.md` など) への参照
   - ADR 同士の参照 / `docs/specs/*` の実在ファイル / 外部パッケージ / その ADR 内で完結する概念は **未定義扱いしない**

3. **状態 (status) 整合性**
   - 本 README の一覧表と各 ADR ファイルの `**状態**` フィールドが一致しているか

### フラグへの対応

| フラグ | 基本方針 | 追加アクション |
|---|---|---|
| **矛盾** | **新しい方を採用** (要ユーザ確認) | 採用されなかった旧 ADR に「置換 (→ NNNN)」または「進化予定」の 1 行注記を追加。状態欄も更新 |
| **未定義参照** | ユーザに問い合わせ | 仕様を書く ([../specs/](../specs/) 配下に追加) か、GitHub Issue (`enhancement` ラベル) に追加するかを選択 |
| **状態不整合** | 事実を確認して片方を合わせる | 一覧表と本文の両方が同じ状態になるよう修正 |

### 運用

- **PR のたび**に Claude Code で `/aidea.docs-healthcheck` を実行 (specs と同時にチェックされる)
- フラグが立ったら PR 内で解消する (別 PR に持ち越さない)
- 問題なしなら特に何もしない (サイレント pass)

