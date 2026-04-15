# Aidea — Specification

> AI + IDE + Idea — 個人用の macOS ネイティブ AI 連携ワークスペース

このドキュメントは Aidea の**動的な仕様書**です。目的・スコープ・MVP 範囲・概念モデルなど、
実装の進行に伴って更新されるものを記述します。

実装フェーズ / 機能要望は GitHub で管理しています:
**Milestones** (Phase ごと) + **Issues** (`enhancement` ラベル)。

静的なルール類は別ファイルに分離されています:

- [architecture.md](./architecture.md) — 技術スタックとコード構造
- [../conventions/coding-style.md](../conventions/coding-style.md) — Swift 規約・並び順・コメント方針
- [../conventions/testing.md](../conventions/testing.md) — テスト戦略と手動チェック
- [boundaries.md](./boundaries.md) — Always / Confirm First / Never
- [glossary.md](./glossary.md) — 用語集

背景と判断理由は [`../foundation/vision.md`](../foundation/vision.md) / [`./tools/`](./tools/) /
[`../decisions/`](../decisions/README.md) を参照。

---

## 1. 目的 (Purpose)

### 何を作るか
macOS ネイティブの個人用 AI コーディングワークスペース。コードエディタは含まず、
ターミナル・WebView・AI エージェント連携・ローカルファイル参照を 1 つのアプリに統合する。

### 誰のためか
- **ターゲット: 開発者本人 1 名のみ**
- 他人への配布、App Store 公開、複数ユーザー対応はしない

### なぜ作るか
- Vibeyard (Electron 製 IDE) の `<webview>` 制約 (Geolocation 不可、OAuth 壊れる、permission 拒否) に
  耐えられず離脱
- 「**本来のブラウザの挙動と差異なく開発できることが最優先**」という原則を満たす
  既製ツールが存在しないため自作する
- 週末プロジェクトとしての「作る楽しみ」と「長期的な自分仕様化」の両立

### 成功基準
- **1 年後 (2027-04 目安)、JetBrains を開く時間より Aidea を開く時間の方が長くなっている**
- MVP 段階の成功基準: ターミナルで Claude Code を起動でき、`~/.claude/skills` の一覧が表示でき、
  WKWebView で localhost プレビューが Safari と同等に動く

---

## 2. 概念モデル (Concept Model)

Aidea の UI は **Window / Pane / Tab / Session / Tool** という 5 つの概念で構成される。

```
Window
 └─ Pane (リサイズ可能な物理区画。HSplitView/VSplitView でツリー状)
     └─ Tab (ペイン内の表示切替単位。1 つの Session を参照する)
         └─ Session (1 つの実体。Window 全体で一意。状態を持つ)
              └─ Tool (機能種別。複数の Session が同じ Tool を共有しうる)
```

用語の定義は [glossary.md](./glossary.md) を参照。

### アクティブ Session の仕組み

- `SessionRegistry.activeSessionID` が Window 全体で 1 つの Active Session を保持
- Tab クリックまたはセッションビュー内のクリック (SwiftUI 領域のみ) で切替
- `activeSessionID` の変更は `activeHistory` に蓄積される (最大 50 件)
- Filer のダブルクリックは履歴から「非 Filer ペインの最新 Session」を探して、そのペインに
  新しい Preview Session タブを作成する

### Session ごとの内部状態

| Tool | `SessionState` の内容 | ペイン移動で保持 |
|---|---|---|
| `filer` | `FileTreeViewController` (展開・選択)・`selectedFile` | ✅ |
| `skills` | `SkillsLoader` + 選択 + グループ開閉 | ✅ |
| `commands` | `CommandsLoader` + 選択 + グループ開閉 | ✅ |
| `mcps` | `McpLoader` + 選択 | ✅ |
| `terminal` | `LocalProcessTerminalView` キャッシュ (PTY 含む) | ✅ |
| `web` | `WKWebView` キャッシュ + 現在 URL | ✅ |
| `preview` | `url: URL?` | ✅ |

### シングルトン制約

- **Filer Tool は Window 全体で 1 つだけ** (UI の `+` メニューで条件付き非表示)
- 他の Tool は同一 Window 内に複数インスタンス可

---

## 3. スコープ (Scope)

### MVP に含むもの

| # | 機能 | 完了条件 |
|---|---|---|
| 1 | ターミナル埋め込み (PTY) | `zsh -l` を projectRoot に cd した状態で起動し、Claude Code CLI を実行できる |
| 2 | WebView (WKWebView) | 任意 URL を表示でき、Geolocation/OAuth popup が Safari と同じ挙動になる |
| 3 | Skills / Commands / MCPs ビュー | `~/.claude/` と `<project>/.claude/` 配下を走査し、frontmatter を抽出して一覧表示できる。USER/PROJECT バッジで区別 |
| 4 | 4 ペイン + マルチタブ | HSplitView + VSplitView で 4 ペイン、各ペインは複数の Tab を持てる。`+` で追加、`×` でクローズ、クリックでアクティブ化 |
| 5 | ファイラ機能 | NSOutlineView ベースのツリー、SF Symbols アイコン、FSEvents による外部変更の自動反映、ダブルクリックで新しい Preview Session を生成 |
| 6 | Preview 機能 | テキスト/画像プレビュー (NSTextView ベース)、バイナリ・サイズ制限付き、ファイル名タブ表示、同一ファイルなら既存タブをアクティブ化 |
| 7 | プロジェクトルートの動的指定 | メニュー「ファイル → ディレクトリを開く」(⌘O) で選んだディレクトリを `WorkspaceState.projectRoot` に設定し、ファイラ・ターミナル cwd・Skills/Commands ローダ全てに反映 |
| 8 | ワークスペース起動 | アプリ起動時、前回開いていた projectRoot があれば自動で復元 (なければ「ディレクトリを開く」を促す) |

### MVP に含まないもの (将来検討)

- Git ビュー (status / diff)
- AI チャット (Claude API 直叩き)
- Obsidian 連携
- ワークスペース (レイアウト + SessionState) の永続化
- MCP サーバーの追加・編集 UI
- セッションログ閲覧
- コストトラッキング
- **複数プロジェクト同時オープン**: 1 Window = 1 プロジェクト固定
- **ファイラの編集系操作** (作成・リネーム・削除・D&D) は MVP 範囲外。閲覧と外部変更検知のみ
- **gitignore / 隠しファイル除外**: MVP では `.git` `node_modules` `DerivedData` `.build` だけ除外、その他は全表示

### 永久にやらないこと

[boundaries.md](./boundaries.md#never-決して行わないこと) の Never セクションを参照。

---

## 4. 実装フェーズ / アイデア

仕様ではなく前段階情報のため、本ドキュメントでは扱わず GitHub 側で管理:

- **Phase ロードマップ** → GitHub Milestones (`gh api repos/:owner/:repo/milestones` または リポジトリの Milestones タブ)
- **個別アイデア・機能要望** → GitHub Issues (`enhancement` ラベル) — `gh issue list --label enhancement`

**永続的にやらないこと**は [boundaries.md](./boundaries.md#never-決して行わないこと) の Never セクションを参照。

---

## 改訂履歴

- 2026-04-08: 初版作成 (MVP 範囲確定、Swift+SwiftUI 採用、外部依存 SwiftTerm のみ)
- 2026-04-08: サポート OS を macOS 15 (Sequoia) 以上に変更
- 2026-04-08: ファイラ機能と動的 projectRoot を MVP に追加 (4 ペイン構成へ更新)
- 2026-04-08: ファイラ機能 / WorkspaceState / FilePreviewView の実装完了 (ADR 0009 参照)
- 2026-04-08: Tool 概念モデルを導入 (Phase 1 開始)。Models/Services をツール別サブディレクトリに再編
- 2026-04-09: Tool/Session/Tab の 3 階層モデルに整理。マルチタブ・シングルトン Filer・Preview ダブルクリック動作追加。Phase 1 完了
- 2026-04-09: SPEC.md を `docs/specs/` 配下に移動。動的/静的で複数ファイルに分割 (SPEC / architecture / coding-style / testing / boundaries / glossary)
