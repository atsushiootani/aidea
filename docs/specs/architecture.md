# Architecture

Aidea の技術スタックとコード構造。動機と原則は [../foundation/vision.md](../foundation/vision.md) を参照。

## 技術スタック

```
┌─────────────────────────────────────────────────┐
│ UI Layer                                        │
│   SwiftUI + AppKit (NSViewRepresentable)        │
├─────────────────────────────────────────────────┤
│ Sessions (7 Tool kinds)                         │
│   Filer / Skills / Commands / MCPs              │
│   Terminal / Web / Preview                      │
├─────────────────────────────────────────────────┤
│ Services                                        │
│   Loaders (Skills/Commands/MCPs)                │
│   Filer (FileTree + FSEvents watcher)           │
│   WorkspaceState + LayoutConfig                 │
├─────────────────────────────────────────────────┤
│ Platform                                        │
│   macOS 15+ (Sequoia) / Swift 5.9+ / Xcode 16+  │
└─────────────────────────────────────────────────┘
```

## プラットフォーム

- **macOS 15 (Sequoia) 以上**
- **Swift 5.9+**
- **Xcode 16+**
- `if #available` による 15 未満への分岐は書かない

## フレームワーク

- **SwiftUI** — UI の主体
- **AppKit** — `NSViewRepresentable` / `NSViewControllerRepresentable` 経由で
  `WKWebView` / `SwiftTerm` / `NSOutlineView` / `NSTextView` をラップ
- **WebKit** — `WKWebView`、`isInspectable = true`
- **CoreServices** — `FSEventStream` でファイルシステム監視
- **Observation** — `@Observable` マクロで State 管理
- **Foundation** / **Security** — Apple 標準

## 外部依存

| パッケージ | 用途 | ライセンス |
|---|---|---|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | PTY + 端末 UI | MIT |

**SwiftTerm 1 個のみ**。他はすべて Apple 標準で代用する (ADR 0006)。

## なぜ Swift + SwiftUI

| 方式 | ブラウザ挙動 | 実装コスト | macOS 統合 | 採否 |
|---|---|---|---|---|
| Electron + TS + React | ✗ `<webview>` 問題 | 低 | 低 | ✗ |
| Tauri + Rust | ✗ WebView 埋込弱い | 中 | 中 | ✗ |
| **Swift + SwiftUI** | **◎ WKWebView=Safari** | **中** | **◎** | **✓** |
| Flutter Desktop | ✗ PTY/WebView 未成熟 | 中 | 低 | ✗ |
| Zed 方式 (Rust GPU) | ◎ | 激高 | ◎ | ✗ (個人には重い) |

**決め手**: WKWebView が本物の Safari エンジン、macOS only と割り切れる、`Process` / `URLSession` / `FileManager` で外部連携が自然。詳細は [ADR 0001](../decisions/0001-swift-swiftui.md)。

## プロジェクト構造

```
Aidea/Aidea/
├─ App/
│   └─ AideaApp.swift              // @main エントリ + メニュー定義
│
├─ Tools/
│   └─ Tool.swift                  // Tool enum, SessionID, SessionState protocol
│
├─ Sessions/                       // Session 実体の状態と管理
│   ├─ SessionRegistry.swift       // activeSessionID / activeHistory の管理
│   ├─ Filer/FilerSessionState.swift
│   ├─ Skills/SkillsSessionState.swift
│   ├─ Commands/CommandsSessionState.swift
│   ├─ Mcps/McpsSessionState.swift
│   ├─ Terminal/TerminalSessionState.swift   // LocalProcessTerminalView キャッシュ
│   ├─ Web/WebSessionState.swift             // WKWebView キャッシュ
│   └─ Preview/PreviewSessionState.swift
│
├─ Services/                       // 副作用層
│   ├─ Workspace/
│   │   ├─ WorkspaceState.swift    // projectRoot の管理
│   │   └─ LayoutConfig.swift      // 4 ペイン Pane 集合
│   ├─ Filer/
│   │   ├─ FileTreeLoader.swift    // ディレクトリ走査
│   │   └─ FileWatcher.swift       // FSEventStream ラッパ
│   ├─ Skills/SkillsLoader.swift
│   ├─ Commands/CommandsLoader.swift
│   └─ Mcps/McpLoader.swift
│
├─ Models/                         // データモデル (Tool 別サブディレクトリ)
│   ├─ Filer/FileTreeNode.swift
│   ├─ Skills/Skill.swift          // ResourceScope enum も含む
│   ├─ Commands/Command.swift
│   └─ Mcps/McpServer.swift
│
├─ Views/
│   ├─ Layout/
│   │   ├─ ContentView.swift       // ルート (4 ペイン分割)
│   │   └─ PaneView.swift          // 1 ペインの容器 (タブバー + 中身の ZStack)
│   ├─ Sessions/                   // Session の SwiftUI ビュー
│   │   ├─ Filer/FilerSessionView.swift   // NSOutlineView ラッパ含む
│   │   ├─ Skills/SkillsSessionView.swift
│   │   ├─ Commands/CommandsSessionView.swift
│   │   ├─ Mcps/McpsSessionView.swift
│   │   ├─ Terminal/TerminalSessionView.swift
│   │   ├─ Web/WebSessionView.swift
│   │   └─ Preview/PreviewSessionView.swift  // NSTextView ラッパ含む
│   └─ Common/
│       ├─ ScopeTagView.swift       // USER/PROJECT バッジ
│       └─ TriangleDisclosureStyle.swift
│
└─ Utilities/
    └─ FrontmatterParser.swift      // YAML frontmatter を正規表現で抽出
```

### 配置ルール

- **1 ファイル = 1 型** (`struct` / `class` / `enum`)
- **Tools/** = 種別 (Tool enum, SessionID, SessionState protocol)
- **Sessions/** = 実体 (各 SessionState、SessionRegistry)
- **Services/** = 副作用 (ファイル I/O、プロセス起動、監視)
- **Views/** = SwiftUI / AppKit ラッパ View
- **Models/** = 純粋データ構造 (@Observable でない)
- **Utilities/** = 純粋関数、ヘルパー

### レイヤー依存方向

```
Views → Sessions → Services → Models
              ↓
           Tools (enum 定義)
```

- View は Session を参照する
- Session は Service と State を参照する
- Service は Models を参照する
- Tools (Tool enum, SessionID) は全体から参照される

## レイアウト (UI)

```
┌──────────────────────────────────────────────────┐
│ Window: Aidea (Title = project directory name) │
├──────────┬────────────────────┬───────────────────┤
│ TopLeft  │                    │                   │
│ Pane     │  Center Pane       │  Right Pane       │
│ (Filer)  │  (Terminal)        │  (Web)            │
├──────────┤                    │                   │
│ BottomL  │                    │                   │
│ (Skills/ │                    │                   │
│ Commands │                    │                   │
│ /MCPs)   │                    │                   │
└──────────┴────────────────────┴───────────────────┘
```

- `HSplitView` で 3 カラム、左カラムは `VSplitView` で上下分割
- 各ペインは `PaneView` 容器で、タブバー + ZStack (全 Tab を常時レンダリング)
- 非アクティブ Tab は `opacity(0)` + `allowsHitTesting(false)` で隠す
  → NSView が superview から外れないので Terminal のバッファが失われない

## データ保存

| データ | 場所 | 用途 |
|---|---|---|
| projectRoot | `UserDefaults` (`aidea.projectRoot`) | 起動時復元 |
| (将来) API キー | macOS Keychain | Claude API セキュア保管 |
| (将来) アプリ設定 | `~/Library/Application Support/Aidea/config.json` | 編集しやすさ |
| (将来) ワークスペース状態 | `~/Library/Application Support/Aidea/workspace.json` | レイアウト + SessionState 復元 (Phase 4)。保存対象: 現在開いているプロジェクト / 各ペインの Session 状態 (表示ファイル / WebView URL / ターミナル cwd 等) / ウィンドウサイズ / スプリット比率 |

## 配布

**個人用のみ**。

- Xcode の Personal Team で署名 (無料、Apple ID 登録のみ)
- ビルド後 `~/Applications/Aidea.app` に配置
- Apple Developer Program ($99/年) 不要
- 公証不要、`xattr -cr` で quarantine を剥がせば OK
- **App Sandbox は無効** (`~/.claude/` 読み取り、PTY 起動のため)

## 関連ドキュメント

- [../foundation/vision.md](../foundation/vision.md) — 動機・原則
- [../conventions/coding-style.md](../conventions/coding-style.md) — コーディング規約
- [../conventions/testing.md](../conventions/testing.md) — テスト戦略
- [boundaries.md](./boundaries.md) — 境界ルール
- [glossary.md](./glossary.md) — 用語集
- [../decisions/](../decisions/README.md) — 設計判断記録
