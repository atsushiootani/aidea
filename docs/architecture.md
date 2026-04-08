# Architecture

## 技術スタック

```
┌─────────────────────────────────────────────────┐
│ UI Layer                                        │
│   SwiftUI + AppKit (NSViewRepresentable)        │
├─────────────────────────────────────────────────┤
│ Feature Modules                                 │
│   - Terminal  (SwiftTerm)                       │
│   - WebView   (WKWebView)                       │
│   - Git       (Process → /usr/bin/git)          │
│   - Claude    (URLSession → api.anthropic.com)  │
│   - Files     (FileManager → ~/.claude/)        │
│   - Obsidian  (URL scheme + FileManager)        │
├─────────────────────────────────────────────────┤
│ Platform                                        │
│   macOS 15+ (Sequoia) / Swift 5.9+ / Xcode 16+  │
└─────────────────────────────────────────────────┘
```

## なぜ Swift + SwiftUI

他の選択肢との比較：

| 方式 | ブラウザ挙動 | 実装コスト | macOS 統合 | 採否 |
|---|---|---|---|---|
| Electron + TS + React | ✗ `<webview>` 問題 | 低 | 低 | ✗ |
| Tauri + Rust | ✗ WebView 埋込弱い | 中 | 中 | ✗ |
| **Swift + SwiftUI** | **◎ WKWebView=Safari** | **中** | **◎** | **✓** |
| Flutter Desktop | ✗ PTY/WebView 未成熟 | 中 | 低 | ✗ |
| Zed 方式（Rust GPU） | ◎ | 激高 | ◎ | ✗（個人には重い） |

**決め手**:
1. **WKWebView が本物の Safari エンジン**。`<webview>` 地獄を回避できる
2. macOS only と割り切れるので、クロスプラットフォームの妥協が不要
3. SwiftUI の宣言的 UI が分割ペイン / ビュー追加に向いている
4. `Process` で git / 外部コマンドを自然に叩ける
5. `URLSession` で Claude API 直接呼び出し

## レイアウト

```
┌──────────────────────────────────────────────────────────┐
│ TopBar: [project ▼] [branch] [settings]                 │
├──────────┬──────────────────────────┬────────────────────┤
│ Sidebar  │   Main                   │   Right Panel      │
│          │                          │                    │
│ 📁 Files │  ┌──────────────────┐   │  ┌──────────────┐  │
│ 🔧 Skills│  │                  │   │  │ WebView      │  │
│ ⚡ Cmds  │  │  Terminal        │   │  │ (WKWebView)  │  │
│ 🔌 MCPs  │  │  (SwiftTerm)     │   │  │              │  │
│ 📝 Notes │  │                  │   │  │              │  │
│ 🌿 Git   │  ├──────────────────┤   │  ├──────────────┤  │
│          │  │ AI Chat          │   │  │ Git Diff     │  │
│          │  │ (Claude API)     │   │  │              │  │
│          │  └──────────────────┘   │  └──────────────┘  │
└──────────┴──────────────────────────┴────────────────────┘
```

SwiftUI の `HSplitView` / `VSplitView` をネストして実装。各ペインはリサイズ可、折りたたみ可。

## モジュール構成（予定）

```
Aidea/
├─ App/
│   └─ AideaApp.swift              // @main
│
├─ Views/
│   ├─ ContentView.swift           // ルート
│   ├─ Sidebar/
│   │   ├─ SkillsListView.swift
│   │   ├─ CommandsListView.swift
│   │   ├─ McpListView.swift
│   │   └─ NotesListView.swift
│   ├─ Main/
│   │   ├─ TerminalView.swift      // SwiftTerm wrap
│   │   └─ ChatView.swift          // Claude API
│   └─ RightPanel/
│       ├─ WebView.swift           // WKWebView wrap
│       └─ GitDiffView.swift
│
├─ Services/
│   ├─ ClaudeClient.swift          // anthropic API
│   ├─ GitService.swift            // Process wrapper
│   ├─ SkillsLoader.swift          // ~/.claude/skills/ 走査
│   ├─ McpLoader.swift
│   └─ ObsidianService.swift       // URL scheme + vault
│
├─ Models/
│   ├─ Skill.swift
│   ├─ Command.swift
│   ├─ McpServer.swift
│   ├─ GitStatus.swift
│   └─ ChatMessage.swift
│
└─ Utilities/
    ├─ KeychainHelper.swift        // API key 保管
    └─ ProcessRunner.swift
```

## 外部依存

最小限に抑える。

| パッケージ | 用途 | ライセンス |
|---|---|---|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | ターミナル UI & PTY | MIT |

他はすべて Apple 標準（Foundation, SwiftUI, AppKit, WebKit, Security）。

## データ保存

| データ | 場所 | 理由 |
|---|---|---|
| API キー (Claude) | macOS Keychain | セキュア |
| アプリ設定 | `~/Library/Application Support/Aidea/config.json` | 編集しやすさ |
| ワークスペース状態 | `~/Library/Application Support/Aidea/workspace.json` | 起動時復元 |
| セッションログ | `~/Library/Application Support/Aidea/logs/` | デバッグ用 |

## 配布

**個人用のみ**。

- Xcode の Personal Team で署名（無料、Apple ID 登録のみ）
- ビルド後 `~/Applications/Aidea.app` に配置
- Apple Developer Program ($99/年) 不要
- 公証不要、`xattr -cr` で quarantine を剥がせばOK
