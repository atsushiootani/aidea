# aidea-mcp

外部ツール (Claude Code 等の MCP クライアント) から Aidea の Companion と通信する stdio 型 MCP サーバ。

Aidea の内部 API には触らず、ファイルベース backchannel ([inbox](../../docs/specs/backchannels/inbox.md) / [rpc](../../docs/specs/backchannels/rpc.md)) の読み書きだけで完結する。設計判断は [ADR 0040](../../docs/decisions/0040-rpc-backchannel-mcp.md) を参照。

## セットアップ

```bash
cd tools/aidea-mcp
npm install
```

## MCP クライアント設定例 (Claude Code)

```json
{
  "mcpServers": {
    "aidea": {
      "command": "node",
      "args": [
        "/path/to/aidea/tools/aidea-mcp/index.js",
        "--workspace", "/path/to/aidea"
      ]
    }
  }
}
```

- `--workspace` には対象ワークスペースのルート (`.aidea/` がある階層) を指定する
- コードは 1 つで、ワークスペースごとに設定エントリの `--workspace` を変えて使い分ける

## 提供ツール

| ツール | 動作 |
|---|---|
| `ask_companion(to, message, timeout?)` | rpc でリクエストを書き、Companion の返事を待って返す。デフォルトタイムアウト 20 秒。タイムアウト時は `request_id` を返すので `get_reply` で後から取得できる |
| `send_to_companion(to, message)` | inbox に書く投げっぱなし送信 (返事なし) |
| `get_reply(request_id)` | 送信済みリクエストの返事を取得 (未着ならその旨を返す) |
| `list_companions()` | Companion の index と名前の一覧 |

`to` は Companion の index (0..8) または名前 (例: `"idea-chan"`)。

## 前提

- **Aidea アプリが起動していること** (配送は Aidea プロセス内の FSEvents 監視が行う)
- 同一マシンのローカルプロセスからの利用のみ (信頼境界は ADR 0037 / 0040 を参照)
