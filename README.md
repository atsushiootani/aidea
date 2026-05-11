# Aidea

> **AI + IDE + Idea** — 個人用の macOS ネイティブ AI 連携ワークスペース

Claude Code をはじめとする AI エージェント連携、本物の WebKit ブラウザ、ターミナル、`~/.claude/` 配下のリソース閲覧を 1 つの macOS アプリに統合する。コードエディタは含まず、既存のエディタ (JetBrains / Neovim 等) と並行して使う。

| | |
|---|---|
| **言語/フレームワーク** | Swift 5.9+ / SwiftUI / WebKit / SwiftTerm |
| **対象** | macOS 15 (Sequoia) 以上 |
| **配布** | 個人用 (Personal Team 署名のみ) |
| **状態** | MVP 実装中 |

## クイックスタート

```bash
git clone https://github.com/atsushiootani/aidea.git
cd aidea
open Aidea/Aidea.xcodeproj
```

Xcode で `⌘R`。**初めて使うとき**は [docs/setup/getting-started.md](./docs/setup/getting-started.md) を一読すると、ビルド → 署名 → ディレクトリを開く → ターミナルで `claude` 起動 → Companion セットアップまで通しで設定できる。ビルド/実行手順の詳細だけ知りたいときは [`Aidea/README.md`](./Aidea/README.md) を参照。

## ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/setup/getting-started.md](./docs/setup/getting-started.md) | 初回ユーザー向けの導入ガイド |
| [docs/specs/](./docs/specs/README.md) | プロダクト仕様 (設計ストック) |
| [Aidea/README.md](./Aidea/README.md) | macOS アプリのビルド/起動手順 |
| [docs/foundation/vision.md](./docs/foundation/vision.md) | 作る動機とプロジェクトの原則 |
| [docs/specs/architecture.md](./docs/specs/architecture.md) | 技術スタック、レイヤー構成 |
| [docs/specs/tools/](./docs/specs/tools/) | 各ツールの実装仕様 (Terminal / Git / Kit / Preview / Obsidian など) |
| [docs/conventions/](./docs/conventions/README.md) | コーディング規約 (Swift 規約 / 設計原則 / テスト戦略) |
| [docs/decisions/](./docs/decisions/README.md) | 設計判断記録 (ADR) |
| [docs/LAYOUT.md](./docs/LAYOUT.md) | docs 配下の配置ルールと命名規約 |
| [CLAUDE.md](./CLAUDE.md) | AI エージェント向けのプロジェクト概要 |

## なぜ作るか (要約)

Vibeyard (Electron 製 IDE) の `<webview>` 制約 (位置情報不可、OAuth 壊れる、permission API 拒否) に耐えられず、**「本来のブラウザの挙動と差異なく開発できることが最優先」** という原則を満たす自作環境を週末プロジェクトとして育てる。詳細は [docs/foundation/vision.md](./docs/foundation/vision.md)。

## ライセンス

個人用プロジェクトのため未定。

---

*このリポジトリは元々 [agent-skills](https://github.com/obra/superpowers) から派生したため、旧 README は [README.agent-skills.md](./README.agent-skills.md) として保存している。*
