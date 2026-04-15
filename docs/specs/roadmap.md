# Roadmap

週末プロジェクトとしての実装スケジュール。時間を区切るのではなく、マイルストーン単位で進める。

## マイルストーン

### M1: ウィンドウが開く

- [ ] Xcode プロジェクト作成
- [ ] SwiftUI の `HSplitView` でレイアウト枠組み
- [ ] 空のサイドバー、メイン、右パネル
- [ ] アプリが `~/Applications/Aidea.app` として起動できる

**完了条件**: ダブルクリックしたらウィンドウが出る。

### M2: ブラウザペインが動く

- [ ] WKWebView を `NSViewRepresentable` でラップ
- [ ] URL バー、戻る/進む/リロード
- [ ] `isInspectable = true` で Safari から DevTools 接続確認
- [ ] localhost:3000 が表示できる

**完了条件**: Aidea のウィンドウ内に本物の Safari が埋まっていて、開発中の Next.js アプリが見える。

### M3: ターミナルが動く

- [ ] SwiftTerm を SPM で追加
- [ ] `LocalProcessTerminalView` を `NSViewRepresentable` でラップ
- [ ] zsh 起動、PWD 追従
- [ ] Claude Code CLI (`claude`) を起動できる

**完了条件**: Aidea 内のターミナルで `claude` を起動し、通常通り対話できる。

### M4: Claude Skills ビュー

- [ ] `~/.claude/skills/` 走査
- [ ] frontmatter パース
- [ ] SwiftUI `List` で表示
- [ ] クリックで詳細ペイン表示
- [ ] フィルタ / 検索

**完了条件**: サイドバーで Claude に登録した skill が全部見える。

### M5: Commands / MCP ビュー

- [ ] `~/.claude/commands/` 走査
- [ ] `~/.claude.json` の `mcpServers` パース
- [ ] それぞれ一覧表示
- [ ] MCP のステータス（running / stopped）表示

**完了条件**: Claude Code に登録済みの skill / command / MCP が Aidea で全部一覧できる。

### M6: Git ビュー

- [ ] `Process` で `git` 叩くラッパ作成
- [ ] `git status --porcelain` で変更ファイル一覧
- [ ] ファイル選択で diff 表示
- [ ] diff は WebView + diff2html で表示
- [ ] 現在ブランチ表示

**完了条件**: Aidea で babytrip の git diff が Vibeyard のそれより見やすく表示される。

### M7: AI チャット

- [ ] Claude API key を Keychain に保存する UI
- [ ] `URLSession` で `/v1/messages` 叩く
- [ ] メッセージ履歴保持
- [ ] ストリーミング対応（SSE）
- [ ] Markdown レンダリング

**完了条件**: Aidea のチャットペインから Claude Opus 4.6 と会話できる。

### M8: Obsidian 連携

- [ ] Vault パス設定
- [ ] URL スキームでノート開く
- [ ] ファイル直書きで新規作成
- [ ] デイリーノート機能（今日の日付で自動生成）
- [ ] AI チャット結果を選択してノートに保存

**完了条件**: Aidea から Obsidian のデイリーノートを開ける、作れる、書き込める。

## 以降（育てるフェーズ）

優先度は気分で決める。ピンときた順に：

- Claude Code セッションログ閲覧
- MCP サーバー追加/削除 UI
- API コストトラッキング
- スクリーンショット → AI 質問ボタン
- ワークスペース保存/復元
- プロジェクト切替
- マルチウィンドウ
- グローバルホットキー（Spotlight 的に Claude に話しかける）
- キーバインド設定
- テーマ切替

## やらないこと（明示）

[vision.md](./vision.md#非要件) 参照。コードエディタ、Linux/Windows 対応、他人への配布、拡張機能システムは **永続的にやらない**。
