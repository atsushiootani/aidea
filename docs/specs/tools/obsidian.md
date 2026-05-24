---
title: Tool 仕様: Obsidian 連携
description: Obsidian vault を URL スキーム + 直接ファイル操作で読み書きする連携 Tool 仕様 (MVP 未実装)
derived_from:
  - docs/decisions/0005-obsidian-hybrid.md
syncs_with: []
impacts: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-17
---

# Tool 仕様: Obsidian 連携

Obsidian vault を読み書きして、デイリーノートや AI との対話ログを外部に残すための連携 Tool。
**MVP では未実装**。将来実装時の仕様メモ。

連携方針は [ADR 0005](../../decisions/0005-obsidian-hybrid.md) で「URL スキーム + 直接ファイル操作のハイブリッド」と決定済み。

---

## 用途想定

- デイリーノートに「今日やったこと」を AI に要約させて書き込む
- Skill の実行履歴をノートとして残す
- Git コミットメッセージからノート生成
- Claude とのチャット履歴を選択的に保存

---

## 連携手段

### 手段 1: URL スキーム (`obsidian://`) — 採用

`NSWorkspace` 経由で `obsidian://` URL を開く。

| URL | 動作 |
|---|---|
| `obsidian://open?vault=X&file=Y` | ノート開く |
| `obsidian://new?vault=X&name=Y&content=Z` | 新規作成 |
| `obsidian://search?vault=X&query=Y` | 検索 |

### 手段 2: Vault を直接読み書き — 採用

Obsidian の vault はただの Markdown ファイルディレクトリ。`FileManager` で直接書き込めば Obsidian 側でもリアルタイム反映。

### 手段 3: Local REST API プラグイン — 将来検討

[obsidian-local-rest-api](https://github.com/coddingtonbear/obsidian-local-rest-api) を入れると HTTP 経由で操作可能。検索・タグ付け・メタデータ操作まで可能。

ADR 0005 の方針により、MVP では導入しない (過剰・追加プラグイン依存)。

---

## 採用方針 (要約)

- **作成・更新**: 手段 2 (ファイル直書き)
- **開く / 検索**: 手段 1 (URL スキーム)
- **メタデータ操作など高度な連携**: 手段 3 を将来検討

---

## 必要な設定

- ユーザーが Vault パスを手動で設定する必要がある (ADR 0005 トレードオフ参照)
- 保存先: アプリ設定ファイル (`~/Library/Application Support/Aidea/config.json` 想定)

---

## 未検討事項

- Tool としての UI (専用ペイン？コマンドパレット？)
- Vault 自動検出 (`~/Documents/Obsidian` などの慣習パス走査)
- 書き込み時のテンプレート機構
- Claude とのチャット履歴を選択的に保存するフロー
