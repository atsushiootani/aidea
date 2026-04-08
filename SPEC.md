# Aidea — Specification

> AI + IDE + Idea — 個人用の macOS ネイティブ AI 連携ワークスペース

このドキュメントは Aidea プロジェクトの仕様書 (Single Source of Truth) です。
背景と判断理由は `docs/vision.md` / `docs/architecture.md` / `docs/features.md` を参照。

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

## 2. スコープ (Scope)

### MVP に含むもの
| # | 機能 | 完了条件 |
|---|---|---|
| 1 | ターミナル埋め込み (PTY) | `zsh -l` を起動し、Claude Code CLI をその中で実行できる |
| 2 | WebView (WKWebView) | 任意 URL を表示でき、Geolocation/OAuth popup が Safari と同じ挙動になる |
| 3 | Skills / Commands / MCPs ビュー | `~/.claude/` 配下を走査し、frontmatter を抽出して一覧表示できる |
| 4 | 分割レイアウト | 左サイドバー + 中央 + 右ペインの 3 ペイン構成をリサイズ可能で表示 |
| 5 | ワークスペース起動 | アプリを開くと上記 4 機能のペインが表示される |

### MVP に含まないもの (将来検討)
- Git ビュー (status / diff)
- AI チャット (Claude API 直叩き)
- Obsidian 連携
- ワークスペース状態の保存/復元
- MCP サーバーの追加・編集 UI
- セッションログ閲覧
- コストトラッキング
- **複数プロジェクト対応**: 現状 `TerminalView` がプロジェクトルートをハードコードしているため、
  ワークスペース切替や cwd 指定 UI を入れる際に解消する

### 永久にやらないこと (非要件)
- ❌ コードエディタ機能
- ❌ Linux / Windows 対応
- ❌ 他人への配布、App Store 公開、有償署名
- ❌ 拡張機能システム
- ❌ Cursor / Copilot 風のエディタ内 AI 補完
- ❌ 設定 UI の作り込み (plist / JSON 直接編集で OK)

---

## 3. 技術スタック (Tech Stack)

### プラットフォーム
- **macOS 15 (Sequoia) 以上** をサポート (もう一台の Mac が Sequoia のため)
- **Swift 5.9+**
- **Xcode 16.4+**

### フレームワーク
- **SwiftUI** (UI 主体)
- **AppKit** (`NSViewRepresentable` 経由で WebKit / SwiftTerm をラップ)
- **WebKit** (`WKWebView`、`isInspectable = true`)
- **Foundation** / **Security** (Keychain) はすべて Apple 標準

### 外部依存
| パッケージ | 用途 | 理由 |
|---|---|---|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | PTY + 端末 UI | Apple 標準だけで PTY を扱うのは現実的でないため |

**SwiftTerm 1 個のみ**。他は必要になった時点で都度検討する (Markdown レンダリング、
YAML パーサ、Keychain ラッパー等は当面 Apple 標準で代用)。

### 配布
- Xcode の Personal Team で署名 (無料)
- ビルド成果物は `~/Applications/Aidea.app` に配置
- Apple Developer Program ($99/年) は契約しない
- 公証なし、`xattr -cr` で quarantine 解除

---

## 4. プロジェクト構造 (Project Structure)

```
Aidea/
├─ App/
│   └─ AideaApp.swift              // @main エントリポイント
│
├─ Views/
│   ├─ ContentView.swift           // ルート (3 ペイン分割)
│   ├─ Sidebar/
│   │   ├─ SkillsListView.swift
│   │   ├─ CommandsListView.swift
│   │   └─ McpListView.swift
│   ├─ Main/
│   │   └─ TerminalView.swift      // SwiftTerm を NSViewRepresentable でラップ
│   └─ RightPanel/
│       └─ WebView.swift           // WKWebView を NSViewRepresentable でラップ
│
├─ Services/
│   ├─ SkillsLoader.swift          // ~/.claude/skills/*/SKILL.md 走査
│   ├─ CommandsLoader.swift        // ~/.claude/commands/*.md 走査
│   └─ McpLoader.swift             // ~/.claude.json 等のパース
│
├─ Models/
│   ├─ Skill.swift
│   ├─ Command.swift
│   └─ McpServer.swift
│
└─ Utilities/
    └─ FrontmatterParser.swift     // YAML frontmatter を正規表現で抽出
```

### 配置ルール
- **1 ファイル = 1 型** (`struct` / `class` / `enum`) を原則とする
- View / Service / Model / Utility をディレクトリで明確に分離
- `Services` は副作用 (ファイル I/O、プロセス起動) を持つ層
- `Views` は `Services` を `@StateObject` / `@Observable` 経由で参照

---

## 5. コードスタイル (Code Style)

### Swift 規約
- Apple の [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) に従う
- インデントは 4 スペース
- 1 行は 120 文字以内を目安
- 型名は `UpperCamelCase`、変数/関数は `lowerCamelCase`

### View 内の変数並び順 (固定)
プロパティラッパは以下の順に並べる:

1. `@Binding`
2. `let`
3. `@State`
4. `@StateObject`
5. `@Query`
6. `@Environment`
7. `@EnvironmentObject`
8. `@FocusState`
9. `var`

### コメント
- すべての `class` / `struct` / `enum` / `func` に**責務を一行で示す**コメントを付ける
- ロジックの「なぜ」を説明するコメントを優先 (「何を」はコードで示す)

### 並行性
- I/O は原則 `async/await`
- メインスレッド更新は `@MainActor`
- `Process` 実行・ファイル走査は別 actor / Task で行う

---

## 6. テスト戦略 (Testing Strategy)

### MVP 方針
- **テストは最小限**。手動動作確認を優先し、まず動くものを作る
- ただし以下は単体テスト対象とする:
  - `FrontmatterParser` (純粋関数、入出力が明確)
  - `SkillsLoader` / `CommandsLoader` / `McpLoader` のパース部分
- フレームワーク: **XCTest** (Apple 標準)

### 手動確認チェック (MVP リリース前)
- [ ] アプリ起動 → 3 ペインが表示される
- [ ] ターミナルペインで `claude` コマンドを実行できる
- [ ] WebView に `https://maps.google.com` を表示し、位置情報ダイアログが macOS から出る
- [ ] サイドバーの Skills 一覧に自分の `~/.claude/skills/` の内容が出る
- [ ] サイドバーの Commands / MCPs 一覧も同様に表示される

### 将来のテスト拡張 (MVP 後)
- UI スナップショットテスト
- Service レイヤの統合テスト

---

## 7. 境界 (Boundaries)

### 常に行うこと (Always)
- 新しいファイルは `Views` / `Services` / `Models` / `Utilities` の責務分類に従って配置する
- 1 ファイル 1 型の原則を守る
- View プロパティラッパは固定順 (5 章) で並べる

### 最初に確認すること (Confirm First)
- 外部依存パッケージを追加する前に必要性を再検討する
  (SwiftTerm 以外は当面追加しない方針のため)
- 非要件 (2 章) に該当する機能を作りそうになったら立ち止まる

### 決して行わないこと (Never)
- ❌ コードエディタ機能を追加しない
- ❌ macOS 以外への対応コードを書かない
- ❌ macOS 15 (Sequoia) 未満の互換コードは書かない
- ❌ 他人配布を前提とした設定 (公証、Developer ID 署名) を組み込まない
- ❌ 設定 UI を作り込まない (JSON / plist 直接編集で済ませる)
- ❌ Vibeyard と同じ罠 (`<webview>` / iframe で本物のブラウザ挙動を犠牲にする) を踏まない

---

## 8. 用語 (Glossary)

| 用語 | 意味 |
|---|---|
| Aidea | 本プロジェクト名。AI + IDE + Idea の合成語 |
| MVP | この SPEC の 2 章「MVP に含むもの」5 機能 |
| 3 ペイン | 左サイドバー + 中央 + 右ペインのレイアウト構成 |
| Vibeyard 問題 | `<webview>` / iframe 制約により本物のブラウザ挙動が得られない現象 |

---

## 改訂履歴
- 2026-04-08: 初版作成 (MVP 範囲確定、Swift+SwiftUI 採用、外部依存 SwiftTerm のみ)
- 2026-04-08: サポート OS を macOS 15 (Sequoia) 以上に変更
