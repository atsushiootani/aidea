# Features

## 1. ターミナル (SwiftTerm)

PTY を埋め込んでネイティブターミナルとして動かす。

```swift
import SwiftTerm

let terminal = LocalProcessTerminalView(frame: .zero)
terminal.startProcess(
    executable: "/bin/zsh",
    args: ["-l"],
    environment: nil
)
```

**要件**:
- 256 色、true color
- エスケープシーケンス完全対応
- マウス報告（クリック、スクロール）
- 複数タブ（将来）
- Claude Code CLI をそのまま起動できる

**参考**: SwiftTerm は iTerm2 の作者 Miguel de Icaza 作、商用 OK。

## 2. WebView (WKWebView)

ローカル開発サーバーのプレビュー、ドキュメント閲覧、AI エージェントへのブラウザ情報受け渡し用。

```swift
import WebKit

let config = WKWebViewConfiguration()
config.preferences.setValue(true, forKey: "developerExtrasEnabled")

let webView = WKWebView(frame: .zero, configuration: config)
if #available(macOS 13.3, *) {
    webView.isInspectable = true  // Safari で Web Inspector 使える
}
webView.load(URLRequest(url: URL(string: "http://localhost:3000")!))
```

**動く機能** (Safari と同等):
- Geolocation (CoreLocation 経由、OS が権限ダイアログ出す)
- WebRTC、カメラ、マイク
- Service Worker
- Notification API
- OAuth popup (`WKUIDelegate` で handle)
- Cookie 永続化

**Chrome との差異**: [webview-notes.md](./webview-notes.md) 参照

## 3. Claude Skills / Commands / MCPs ビュー

`~/.claude/` 以下を走査して SwiftUI で一覧表示。

### データソース

| ビュー | パス | フォーマット |
|---|---|---|
| Skills | `~/.claude/skills/*/SKILL.md` | Markdown + frontmatter |
| Commands | `~/.claude/commands/*.md` | Markdown + frontmatter |
| MCP Servers | `~/.claude.json` もしくは `~/Library/Application Support/Claude/claude_desktop_config.json` | JSON |
| Projects | `~/.claude/projects/<encoded-path>/` | ディレクトリ |
| Sessions | `~/.claude/projects/<encoded-path>/*.jsonl` | JSONL |

### frontmatter パース

Skills/Commands の `.md` ファイル先頭にある YAML frontmatter を抽出：

```yaml
---
name: skill-name
description: What this skill does
---
```

Swift で軽量な YAML パーサ or 正規表現で frontmatter だけ抽出。

### UI

- `List` で一覧
- 選択すると詳細（description、使用例、該当ファイルへのパス）
- クリックでファイルを Finder で開く or Obsidian で開く or コピー
- 検索ボックスで絞り込み
- タグ / カテゴリ表示（frontmatter から）

## 4. Git ビュー

### データ取得

`Process` で `git` コマンドを叩く。

```swift
func runGit(_ args: [String], cwd: URL) async throws -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    p.arguments = args
    p.currentDirectoryURL = cwd
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    try p.run()
    p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                  encoding: .utf8) ?? ""
}
```

### 表示内容

| 項目 | コマンド |
|---|---|
| 現在のブランチ | `git rev-parse --abbrev-ref HEAD` |
| 変更ファイル一覧 | `git status --porcelain` |
| Diff | `git diff <file>` / `git diff --cached <file>` |
| Log | `git log --oneline -20` |

### Diff 表示の実装

2 案：

**案A: WKWebView + diff2html**
- `git diff` の出力を [diff2html](https://diff2html.xyz/) の HTML に変換して WebView で表示
- 見た目最強、シンタックスハイライト付き
- 既に WebView 使ってるので追加コストほぼ無い

**案B: SwiftUI でネイティブ描画**
- 行ごとに色付け
- フォント、色、動作をフル制御できる
- ハイライトは Splash など別途必要

→ **案 A を採用**。WebView ビューに特別 URL `aidea://git-diff/...` で流し込む。

## 5. AI チャット

### Claude API 直叩き

```swift
func chat(messages: [Message]) async throws -> String {
    var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    req.addValue(apiKey, forHTTPHeaderField: "x-api-key")
    req.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    req.httpBody = try JSONSerialization.data(withJSONObject: [
        "model": "claude-opus-4-6",
        "max_tokens": 4096,
        "messages": messages.map { ["role": $0.role, "content": $0.content] }
    ])
    let (data, _) = try await URLSession.shared.data(for: req)
    // parse JSON
    return content
}
```

### モデル

- デフォルト: `claude-opus-4-6`
- 設定で切り替え可（Sonnet 4.6, Haiku 4.5 など）

### 機能

- ストリーミングレスポンス（SSE）
- 会話履歴保持
- コードブロックのシンタックスハイライト
- Git diff / skills などをコンテキストとして添付可
- Markdown レンダリング（SwiftUI 標準 `Text` の markdown 対応 or MarkdownUI ライブラリ）

**注意**: Claude Code CLI そのものはターミナルで動かすため、このチャットビューは **サブ的な役割**（クイック質問、コンテキスト付き質問用）。メインの開発対話はターミナル内で Claude Code に任せる。

## 6. Obsidian 連携

### 用途想定

- デイリーノートに「今日やったこと」を AI に要約させて書き込む
- Skill の実行履歴をノートとして残す
- Git コミットメッセージからノート生成
- Claude とのチャット履歴を選択的に保存

### 連携手段

**手段 1: URL スキーム (`obsidian://`)**

```swift
// 特定のノートを Obsidian で開く
let url = URL(string: "obsidian://open?vault=MyVault&file=daily/2026-04-08")!
NSWorkspace.shared.open(url)
```

| URL | 動作 |
|---|---|
| `obsidian://open?vault=X&file=Y` | ノート開く |
| `obsidian://new?vault=X&name=Y&content=Z` | 新規作成 |
| `obsidian://search?vault=X&query=Y` | 検索 |

**手段 2: Vault を直接読み書き**

Obsidian の vault はただの Markdown ファイルディレクトリ。`FileManager` で直接書き込めば Obsidian 側でもリアルタイム反映。

```swift
let vaultURL = URL(fileURLWithPath: "/Users/atsushi/Obsidian/MyVault")
let noteURL = vaultURL.appendingPathComponent("daily/\(todayString).md")
try markdown.write(to: noteURL, atomically: true, encoding: .utf8)
```

**手段 3: Local REST API プラグイン**

[obsidian-local-rest-api](https://github.com/coddingtonbear/obsidian-local-rest-api) を入れると HTTP 経由で操作可能。検索・タグ付け・メタデータ操作まで可能。

**採用方針**: 手段 1 + 手段 2 のハイブリッド。作成・更新はファイル直書き、開くときは URL スキーム。REST API は将来的に。

## 7. ワークスペース管理

- 現在開いているプロジェクト
- 各ペインの状態（表示中のファイル、WebView の URL、ターミナルの cwd）
- ウィンドウサイズ / スプリット比率

`~/Library/Application Support/Aidea/workspace.json` に保存し、起動時に復元。
