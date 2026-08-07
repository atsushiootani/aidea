---
title: Tool 仕様: Kit
description: Skills / Commands / Agents / MCPs の 4 セクションを 1 ペインで閲覧する Kit Tool 仕様 (Window singleton / FSEvents 自動更新)
derived_from:
  - docs/specs/sessions/ui-rules.md
  - docs/specs/window/
syncs_with:
  - docs/specs/sessions/kit.md
  - docs/specs/aspects/keybindings.md
  - docs/specs/aspects/sort-order.md
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-07-13
---

# Tool 仕様: Kit

Claude の "装備品一式" (Skills / Commands / Agents / MCPs) を 1 つの Tool にまとめたもの。

概念モデルは [sessions/ui-rules.md#概念モデル](../sessions/ui-rules.md#概念モデル) / [glossary.md](../glossary.md) を参照。
Session 内部状態は [sessions/kit.md](../sessions/kit.md) を参照。
全ツール共通の UI 規約は [sessions/ui-rules.md](../sessions/ui-rules.md) と [window/](../window/README.md) を参照。

---

## 概要

- Claude Code エコシステムの 4 種類のリソースを 1 つのペインで閲覧する Tool
- **Window 内 singleton**: Aidea Window に 1 つだけ存在する (Filer / Git と同等)。Tool 追加メニューから 2 個目以降は追加不可
- **4 つのセクション**を縦並びのアコーディオン UI で表示 (すべて同時に展開可能)
- 各セクションは折りたたみ可、ヘッダーに件数を表示
- Skills / Commands は `~/.claude/` と `<projectRoot>/.claude/` の両方を走査し、USER / PROJECT バッジで区別
- **FSEvents で `.claude/` 配下を監視し、外部での変更を自動反映**する (詳細: [#自動更新](#自動更新))
- 既存の [Skills / Commands / MCPs Tool はこの Kit に統合され廃止される](#廃止される-tool)

## 廃止される Tool

- `skills` → Kit の Skills セクションに統合
- `commands` → Kit の Commands セクションに統合
- `mcps` → Kit の MCPs セクションに統合

Tool 種別からは Skills / Commands / MCPs が削除され、新たに Kit が追加される。
Agents セクションは新規 (既存 Tool からの移行ではない)。

---

## セクション構成

| セクション | データソース | スコープ | ステータスバッジ |
|---|---|---|---|
| **AGENTS** | `~/.claude/agents/*.md` + `<projectRoot>/.claude/agents/*.md` | USER / PROJECT | 将来: `inherit` など |
| **SKILLS** | `~/.claude/skills/*/SKILL.md` + `<projectRoot>/.claude/skills/*/SKILL.md` | USER / PROJECT | (なし) |
| **COMMANDS** | `~/.claude/commands/*.md` + `<projectRoot>/.claude/commands/*.md` | USER / PROJECT | (なし) |
| **MCP SERVERS** | `~/.claude.json` の `mcpServers` | USER | `configured` (全件) |

セクション順は上記表の通り (AGENTS → SKILLS → COMMANDS → MCP SERVERS)。

各セクション内のエントリ並び順、および Skills / Commands の名前グループキーの並び順は
**Filer と同じ Finder 互換自然順** を使う。
同名で USER / PROJECT が両方存在する場合は **PROJECT を前に置く** (PROJECT が USER を上書きする関係性を可視化)。
詳細は [aspects/sort-order.md](../aspects/sort-order.md) を参照。

---

## 機能

### toggleSection — セクションの折りたたみ/展開
- 各セクションヘッダーをクリックするとその配下の一覧をトグル表示
- 展開状態は SessionState に保持され、ペイン移動や再起動で復元される (Phase 4 で永続化対応予定)

### addResource — セクション別の新規追加 (ヘッダーの `+` ボタン)
- **MCPs**: `claude_desktop_config.json` への追加用 UI (Phase 5 で実装、MVP では非活性 or 非表示)
- **Agents / Skills / Commands**: 将来検討 (MVP では非活性 or 非表示)
- どのセクションに `+` ボタンを出すかは実装時に決定

### openDetail — 項目の詳細を開く
- 行を **ダブルクリック**するとその項目を Preview Session に開く
- Skills / Commands の場合: `SKILL.md` / `<name>.md` ファイルをプレビュー
- Agents の場合: エージェント定義ファイル (`~/.claude/agents/<name>.md`) をプレビュー
- MCPs の場合: `~/.claude.json` のプレビュー (MVP では簡易表示でも可)
- Preview の配置ルールは Filer と同じ共通の Preview 起動経路に従う。開く前に Kit 自身をアクティブ Session にし、配置先決定 (活動履歴ベース) に自分を起点として伝える ([sessions/active-session.md#preview-を開くときの呼び出し規約](../sessions/active-session.md#preview-を開くときの呼び出し規約))
- 項目の表示名 (例: `diagram.architecture`) をタブタイトルとして渡し、Preview タブのヘッダーに `SKILL.md` ではなく意味のある名前を表示する

### searchInKit — セクション横断インクリメンタル検索 (将来)
- Cmd+F でヘッダー上部に検索バー、全セクション横断で名前をフィルタ
- MVP では未実装、Phase 5 で検討

---

## 自動更新

Filer / Git と同じ FSEvents ベースのファイル監視を使い、外部エディタでの追加・削除・内容変更を即座に Kit 表示へ反映する。手動更新ボタンは設けない。

### 監視対象

| パス | カバーするリソース |
|---|---|
| `~/.claude/` | USER スコープの Agents / Skills / Commands |
| `<projectRoot>/.claude/` | PROJECT スコープの Agents / Skills / Commands |

Kit は **Window 内 singleton** なので、監視も Window に 1 つだけ (Filer / Git と同じ制御)。
2 つの監視パスは 1 つの監視ストリームでまとめて扱う。

### 挙動

- 監視パス配下でファイルイベントが起きたら **200ms デバウンス後に全セクションを再読み込み**する (連続イベントで過剰 reload しないため)
- `projectRoot` が変化したら監視対象のプロジェクトパスを差し替えて監視を張り直す
- Session 破棄時に監視を停止する

### `~/.claude.json` (MCP 設定) の扱い

`~/.claude.json` は単一ファイルで FSEvents の直接監視が難しいため、個別の監視は設けない。代わりに以下でカバー:

- `~/.claude/` 配下の任意の変更時の再読み込みが MCP もまとめて再読み込みする
- Kit Session 活性化時 (表示されたタイミング) の再読み込みも維持する

→ MCP だけ単独変更した場合の即時反映は見送る。実運用で問題になれば将来拡張。

---

## 行レイアウト

各行は **3 カラム構成**:

```
[name]                     [status]   [scope]
gitnexus-exploring         configured  USER
/commit                                 USER
notion                     configured   USER
code-reviewer              inherit      USER
```

- **name**: 項目名 (Commands は先頭に `/` を付ける、それ以外は生の名前)
- **status**: ステータスバッジ (configured / inherit など)。該当なしの項目は空
- **scope**: USER / PROJECT バッジ (他ツールと共通のスコープバッジ)

### 名前グループ化 (Skills / Commands)
- 旧 Skills/Commands Tool と同じく、名前の `.` / `-` 前方一致でサブグループ化する
- セクションの中にさらに折りたたみ可能なグループが入るネスト構造
- 例: `gitnexus-cli` `gitnexus-debugging` `gitnexus-exploring` は `gitnexus` グループにまとまる
- グループの開閉状態もセクション同様 SessionState に保持 (ペイン移動で維持)
- サブグループの開閉矢印はセクションヘッダーと同じ見た目
- Agents / MCPs にはグループ化を適用しない

---

## セクションヘッダー

```
┌───────────────────────────────────────┐
│ ▼ AGENTS                    1    +    │
├───────────────────────────────────────┤
│  code-reviewer  inherit  USER          │
├───────────────────────────────────────┤
│ ▼ SKILLS                    54   +    │
├───────────────────────────────────────┤
│  gitnexus-exploring            USER    │
│  ... (53 more)                         │
├───────────────────────────────────────┤
│ ▼ COMMANDS                  10   +    │
├───────────────────────────────────────┤
│  /commit                        USER   │
└───────────────────────────────────────┘
```

- **▼ / ▶**: 展開/折りたたみ矢印 (SF Symbols の `play.fill` を 90 度回転した開閉三角形)
- **セクション名**: 大文字、太字
- **件数**: 右寄せ (小さめ、灰色)
- **`+` ボタン**: 件数の右隣 (該当セクションのみ表示)

---

## キーボード操作

| キー | 機能 |
|---|---|
| **↑ / ↓** | 行選択の上下移動 (セクションまたぎ可) |
| **Enter** | [openDetail](#opendetail--項目の詳細を開く) |
| **← / →** | 現在行が属するセクションを折りたたみ/展開 |
| **Ctrl + P / N / F / B** | [Emacs ライクナビゲーション](../sessions/ui-rules.md#キーボードナビゲーション-emacs-ライク) (F/B はセクションの展開/折りたたみにマップ) |
| **Ctrl + V / Z** | ページ送り |
| **Cmd + F** | searchInKit (将来) |

---

## マウス操作

| 操作 | 機能 |
|---|---|
| シングルクリック | 行選択 |
| ダブルクリック | [openDetail](#opendetail--項目の詳細を開く) |
| セクションヘッダークリック | [toggleSection](#togglesection--セクションの折りたたみ展開) |
| ヘッダー `+` ボタンクリック | [addResource](#addresource--セクション別の新規追加-ヘッダーの--ボタン) |
| 右クリック | コンテキストメニュー ([共通ルール](../sessions/ui-rules.md#右クリックコンテキストメニュー)) |

### コンテキストメニュー項目
- **プレビューで開く** (Enter)
- **外部エディタで開く** (将来)
- **Finder で表示** (将来)
- **パスをコピー** (将来)

---

## 未検討事項 (将来)

- 新規作成 UI (各セクションの `+` ボタン) の実装
- Cmd+F による横断検索
- 外部エディタで開く / Finder で表示 / パスコピー
- MCP Servers の `configured` 以外のステータス (未接続など)
- Agent の `inherit` 実装詳細
- セクション並び替え・非表示設定
- 件数のフィルタリング (検索時)
- `~/.claude.json` 単独変更の即時反映 (現状は他リソース変更や Kit 再活性化にピギーバック)
