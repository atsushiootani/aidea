# Vision

## 作る理由

### 試した道: Vibeyard
Electron 製の AI コーディング IDE（Vibeyard）を試したが、以下の問題が判明：

- `<webview>` タグの制約で **位置情報 (Geolocation) が取れない**
- `<webview>` の popup ハンドリング欠如で **OAuth ログインが壊れる**
- `permission request handler` が未設定で多くの Web API が拒否される
- User-Agent が Electron 由来でサイトによっては bot 扱い
- Chrome プロファイル（Cookie、拡張機能）が使えない

Vibeyard の Inspect / Flow Recording 機能自体は面白いが、**IDE 固有のバグと永続的に付き合うデメリットが、統合 UX のメリットを上回る**と判断。

### 判断
- Vibeyard は使わない
- 当面の実用環境は **Chrome + Playwright MCP + Claude Code** の組み合わせで済ませる
- **「作る楽しみ」と「長期的な自分仕様」の両立**のため、週末プロジェクトとして自作 IDE を育てる

### 原則
> **本来のブラウザの挙動と差異なく開発できることが最優先**
>
> 統合された UX は便利だが、それは手段。本物のブラウザで動くものが動かなかったり、挙動が違ったりすることに耐えてまで統合は求めない。

## 要件

### 機能要件（MVP）

| 機能 | 優先度 |
|---|---|
| ターミナル埋め込み（PTY） | ★★★ |
| WKWebView で Web プレビュー | ★★★ |
| Claude の skills / commands / MCP 一覧ビュー | ★★★ |
| Git status / diff 表示 | ★★★ |
| Claude API 直接呼び出しチャット | ★★ |
| Obsidian 連携（ノート作成、開く） | ★★ |
| 分割レイアウト（左サイド、中央、右サイド） | ★★★ |

### 機能要件（将来）

| 機能 | 備考 |
|---|---|
| MCP サーバー管理 UI | 追加・削除・設定編集 |
| Claude Code セッションログ閲覧 | `~/.claude/projects/` 解析 |
| コストトラッキング | API 使用量可視化 |
| スクリーンショット → AI 質問 | 画面キャプチャ→ペースト |
| ワークスペース保存/復元 | レイアウトと開いていたビューを記憶 |

### 非要件

明示的に **やらない** ことを決めておく：

- ❌ **コードエディタ機能**: JetBrains 系を継続使用、将来は Neovim 等に移行予定。Aidea にエディタは組み込まない
- ❌ **Linux / Windows 対応**: macOS 専用でよい
- ❌ **他人への配布**: 自分 1 人で使えれば OK。App Store 公開や他人向け署名は不要
- ❌ **拡張機能システム**: 自分で直接コード書き換えればよい
- ❌ **Cursor / Copilot のようなエディタ内 AI 補完**: エディタ自体を持たないため不要
- ❌ **設定 UI の作り込み**: plist / JSON 直接編集で OK

## 成功基準

> **1 年後、JetBrains を開く時間より Aidea を開く時間の方が長くなっている**

そして、その時点で：
- Obsidian のデイリーノートから今日やることを Claude に渡して始められる
- Git diff を Aidea で見て、AI に解説してもらえる
- Playwright MCP や Claude Skills を GUI で管理できる
- 新しいアイデアを思いついたら、Aidea 自身に機能を追加できる
