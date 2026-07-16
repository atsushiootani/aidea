# Aidea

個人用の macOS ネイティブ AI 連携ワークスペース。Swift + SwiftUI 製。
詳細は [docs/specs/](./docs/specs/README.md) と [docs/decisions/](./docs/decisions/README.md) を参照。

## トップレベル構成

```
Aidea/             → macOS アプリ本体 (Xcode プロジェクト)
docs/              → 設計ドキュメント (specs / conventions / foundation / decisions)。配置ルールは docs/LAYOUT.md
skills/            → agent-skills 由来の参照リソース
.claude/           → ローカル個人のスキル/コマンド (gitignore、共有しない)
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
| プロダクト仕様 (設計ストック) | [docs/specs/](./docs/specs/README.md) |
| 動機・原則・成功基準 | [docs/foundation/vision.md](./docs/foundation/vision.md) |
| ビルド & 起動方法 | [Aidea/README.md](./Aidea/README.md) |
| なぜこの技術選定？ | [docs/decisions/](./docs/decisions/README.md) |
| 全体像 / 経緯 | [docs/foundation/vision.md](./docs/foundation/vision.md) |
| アーキテクチャ詳細 | [docs/specs/architecture.md](./docs/specs/architecture.md) |
| 各ツールの実装仕様 | [docs/specs/tools/](./docs/specs/tools/) |
| コーディング規約 | [docs/conventions/](./docs/conventions/README.md) |
| docs 配下の配置ルール | [docs/LAYOUT.md](./docs/LAYOUT.md) |

## 開発時の注意

- 新しい設計判断は [`docs/decisions/`](./docs/decisions/README.md) に ADR として追記する
- `docs/` 以下にファイル追加・移動・リネームを行うときは [docs/LAYOUT.md](./docs/LAYOUT.md) の配置ルールと命名規約に従う
- View プロパティラッパの並び順は [docs/conventions/coding-style.md](./docs/conventions/coding-style.md) のルールに従う
- 1 ファイル 1 型 (struct/class/enum) を原則とする
- ターミナルから `claude` を自動起動してはならない (理由: [ADR 0008](./docs/decisions/0008-no-claude-autostart.md))
- 機能群の変更時は [docs/specs/aspects/](./docs/specs/aspects/README.md)（横断的関心事）も合わせて更新する
- **新機能・新チャネルの specs を書く前に、類似の既存機能（命名・ファイル形式・UI 作法）を洗い出して揃える**。[docs/conventions/design-principles.md](./docs/conventions/design-principles.md) のチェックリストを通すこと
