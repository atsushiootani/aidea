# Aidea

個人用の macOS ネイティブ AI 連携ワークスペース。Swift + SwiftUI 製。
詳細は [SPEC.md](./SPEC.md) と [docs/decisions/](./docs/decisions/README.md) を参照。

## トップレベル構成

```
SPEC.md            → 仕様書 (Single Source of Truth)
Aidea/             → macOS アプリ本体 (Xcode プロジェクト)
docs/              → 設計ドキュメント (vision / architecture / features / ADR)
skills/            → agent-skills 由来の参照リソース
.claude/           → このプロジェクト固有のスキル/コマンド
```

旧 agent-skills の説明は [CLAUDE.agent-skills.md](./CLAUDE.agent-skills.md) に退避。

## 重要な境界

- **macOS 15 (Sequoia) 以上**を最低ターゲット
- 外部依存は **SwiftTerm のみ** (それ以外は Apple 標準で代用)
- **App Sandbox は無効** (`~/.claude/` 読み取りと PTY 起動のため)
- コードエディタ機能は **持たない** (JetBrains/Neovim 等を併用)
- ADR で固定された決定は [`docs/decisions/`](./docs/decisions/README.md) を必ず確認してから変更する

## よく参照するドキュメント

| 知りたいこと | 参照先 |
|---|---|
| 仕様 / MVP 範囲 / 境界 | [SPEC.md](./SPEC.md) |
| ビルド & 起動方法 | [Aidea/README.md](./Aidea/README.md) |
| なぜこの技術選定？ | [docs/decisions/](./docs/decisions/README.md) |
| 全体像 / 経緯 | [docs/vision.md](./docs/vision.md) |
| アーキテクチャ詳細 | [docs/architecture.md](./docs/architecture.md) |
| 機能の実装メモ | [docs/features.md](./docs/features.md) |

## 開発時の注意

- 新しい設計判断は [`docs/decisions/`](./docs/decisions/README.md) に ADR として追記する
- View プロパティラッパの並び順は SPEC.md 5 章のルールに従う
- 1 ファイル 1 型 (struct/class/enum) を原則とする
- ターミナルから `claude` を自動起動してはならない (理由: [ADR 0008](./docs/decisions/0008-no-claude-autostart.md))
